import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/instagram_account.dart';
import '../models/instagram_user.dart';
import '../models/profile.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static const _dbVersion = 3; // Incremented version to recreate with proper boolean types

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'igfollowmgr.db');
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Instagram Accounts table
    await db.execute('''
      CREATE TABLE instagram_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT,
        sessionId TEXT,
        csrfToken TEXT,
        isActive INTEGER NOT NULL DEFAULT 1,
        lastLogin TEXT,
        lastSync TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Profiles table (cached profile data)
    await db.execute('''
      CREATE TABLE profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        display_name TEXT,
        profile_picture_url TEXT,
        bio TEXT,
        followers_count INTEGER,
        following_count INTEGER,
        posts_count INTEGER,
        is_verified INTEGER NOT NULL DEFAULT 0,
        is_private INTEGER NOT NULL DEFAULT 0,
        last_sync TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Followers table
    await db.execute('''
      CREATE TABLE followers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        username TEXT NOT NULL,
        full_name TEXT,
        profile_picture_url TEXT,
        is_verified INTEGER NOT NULL DEFAULT 0,
        is_private INTEGER NOT NULL DEFAULT 0,
        is_business INTEGER NOT NULL DEFAULT 0,
        external_url TEXT,
        followers_count INTEGER,
        following_count INTEGER,
        posts_count INTEGER,
        biography TEXT,
        followed_at TEXT,
        last_seen TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES instagram_accounts (id) ON DELETE CASCADE,
        UNIQUE(account_id, username)
      )
    ''');

    // Following table
    await db.execute('''
      CREATE TABLE following (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        username TEXT NOT NULL,
        full_name TEXT,
        profile_picture_url TEXT,
        is_verified INTEGER NOT NULL DEFAULT 0,
        is_private INTEGER NOT NULL DEFAULT 0,
        is_business INTEGER NOT NULL DEFAULT 0,
        external_url TEXT,
        followers_count INTEGER,
        following_count INTEGER,
        posts_count INTEGER,
        biography TEXT,
        following_at TEXT,
        last_seen TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES instagram_accounts (id) ON DELETE CASCADE,
        UNIQUE(account_id, username)
      )
    ''');

    // Sync queue table (for tracking pending sync operations)
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        operation_type TEXT NOT NULL,
        target_username TEXT NOT NULL,
        action TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES instagram_accounts (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_followers_account_id ON followers(account_id)');
    await db.execute('CREATE INDEX idx_followers_username ON followers(username)');
    await db.execute('CREATE INDEX idx_following_account_id ON following(account_id)');
    await db.execute('CREATE INDEX idx_following_username ON following(username)');
    await db.execute('CREATE INDEX idx_sync_queue_account_id ON sync_queue(account_id)');
    await db.execute('CREATE INDEX idx_sync_queue_status ON sync_queue(status)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Simple upgrade strategy: drop and recreate
      await db.execute('DROP TABLE IF EXISTS instagram_accounts');
      await db.execute('DROP TABLE IF EXISTS profiles');
      await db.execute('DROP TABLE IF EXISTS instagram_users');
      await db.execute('DROP TABLE IF EXISTS followers');
      await db.execute('DROP TABLE IF EXISTS following');
      await db.execute('DROP TABLE IF EXISTS sync_queue');
      await _onCreate(db, newVersion);
    }
  }

  // Get a single Instagram account by username
  Future<InstagramAccount?> getInstagramAccount(String username) async {
    final db = await database;
    final maps = await db.query(
      'instagram_accounts',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (maps.isNotEmpty) {
      final map = maps.first.map((key, value) => MapEntry(key, value));
      map['isActive'] = map['isActive'] == 1;
      return InstagramAccount.fromJson(map);
    }
    return null;
  }

  // Get all Instagram accounts
  Future<List<InstagramAccount>> getAllInstagramAccounts() async {
    final db = await database;
    final maps = await db.query('instagram_accounts');
    
    return maps.map((map) {
      final newMap = map.map((key, value) => MapEntry(key, value));
      newMap['isActive'] = newMap['isActive'] == 1;
      return InstagramAccount.fromJson(newMap);
    }).toList();
  }

  // Insert an Instagram account into the database
  Future<int> insertInstagramAccount(InstagramAccount account) async {
    final db = await database;
    final map = account.toJson();
    map['isActive'] = account.isActive ? 1 : 0;
    
    return await db.insert(
      'instagram_accounts',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Update an Instagram account
  Future<int> updateInstagramAccount(InstagramAccount account) async {
    final db = await database;
    final map = account.toJson();
    map['isActive'] = account.isActive ? 1 : 0;
    
    return await db.update(
      'instagram_accounts',
      map,
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> deleteInstagramAccount(int id) async {
    final db = await database;
    return await db.delete(
      'instagram_accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Profile CRUD operations
  Future<int> insertProfile(Profile profile) async {
    final db = await database;
    return await db.insert('profiles', profile.toJson());
  }

  Future<Profile?> getProfileByUsername(String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'profiles',
      where: 'username = ?',
      whereArgs: [username],
    );
    if (maps.isNotEmpty) {
      return Profile.fromJson(maps.first);
    }
    return null;
  }

  Future<int> updateProfile(Profile profile) async {
    final db = await database;
    return await db.update(
      'profiles',
      profile.toJson(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  // Followers CRUD operations
  Future<int> insertFollower(InstagramUser follower, int accountId) async {
    final db = await database;
    
    // Create a clean data map with only the fields we need for the database
    final followerData = {
      'account_id': accountId,
      'username': follower.username,
      'full_name': follower.fullName,
      'profile_picture_url': follower.profilePictureUrl,
      'is_verified': follower.isVerified ? 1 : 0,
      'is_private': follower.isPrivate ? 1 : 0,
      'is_business': follower.isBusiness ? 1 : 0,
      'external_url': follower.externalUrl,
      'followers_count': follower.followersCount,
      'following_count': follower.followingCount,
      'posts_count': follower.postsCount,
      'biography': follower.biography,
      'followed_at': follower.followedAt?.toIso8601String(),
      'last_seen': follower.lastSeen?.toIso8601String(),
      'created_at': follower.createdAt.toIso8601String(),
      'updated_at': follower.updatedAt.toIso8601String(),
    };
    
    return await db.insert('followers', followerData);
  }

  Future<List<InstagramUser>> getFollowers(int accountId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'followers',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'followed_at DESC',
    );
    return List.generate(maps.length, (i) {
      final map = maps[i];
      // Convert integer values back to booleans for SQLite compatibility
      map['is_verified'] = map['is_verified'] == 1;
      map['is_private'] = map['is_private'] == 1;
      map['is_business'] = map['is_business'] == 1;
      return InstagramUser.fromJson(map);
    });
  }

  Future<InstagramUser?> getFollowerByUsername(int accountId, String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'followers',
      where: 'account_id = ? AND username = ?',
      whereArgs: [accountId, username],
    );
    if (maps.isNotEmpty) {
      final map = maps.first;
      // Convert integer values back to booleans for SQLite compatibility
      map['is_verified'] = map['is_verified'] == 1;
      map['is_private'] = map['is_private'] == 1;
      map['is_business'] = map['is_business'] == 1;
      return InstagramUser.fromJson(map);
    }
    return null;
  }

  Future<int> updateFollower(InstagramUser follower, int accountId) async {
    final db = await database;
    
    // Create a clean data map with only the fields we need for the database
    final followerData = {
      'account_id': accountId,
      'username': follower.username,
      'full_name': follower.fullName,
      'profile_picture_url': follower.profilePictureUrl,
      'is_verified': follower.isVerified ? 1 : 0,
      'is_private': follower.isPrivate ? 1 : 0,
      'is_business': follower.isBusiness ? 1 : 0,
      'external_url': follower.externalUrl,
      'followers_count': follower.followersCount,
      'following_count': follower.followingCount,
      'posts_count': follower.postsCount,
      'biography': follower.biography,
      'followed_at': follower.followedAt?.toIso8601String(),
      'last_seen': follower.lastSeen?.toIso8601String(),
      'created_at': follower.createdAt.toIso8601String(),
      'updated_at': follower.updatedAt.toIso8601String(),
    };
    
    return await db.update(
      'followers',
      followerData,
      where: 'account_id = ? AND username = ?',
      whereArgs: [accountId, follower.username],
    );
  }

  Future<int> deleteFollower(int accountId, String username) async {
    final db = await database;
    return await db.delete(
      'followers',
      where: 'account_id = ? AND username = ?',
      whereArgs: [accountId, username],
    );
  }

  // Following CRUD operations
  Future<int> insertFollowing(InstagramUser following, int accountId) async {
    final db = await database;
    
    // Create a clean data map with only the fields we need for the database
    final followingData = {
      'account_id': accountId,
      'username': following.username,
      'full_name': following.fullName,
      'profile_picture_url': following.profilePictureUrl,
      'is_verified': following.isVerified ? 1 : 0,
      'is_private': following.isPrivate ? 1 : 0,
      'is_business': following.isBusiness ? 1 : 0,
      'external_url': following.externalUrl,
      'followers_count': following.followersCount,
      'following_count': following.followingCount,
      'posts_count': following.postsCount,
      'biography': following.biography,
      'following_at': following.followingAt?.toIso8601String(),
      'last_seen': following.lastSeen?.toIso8601String(),
      'created_at': following.createdAt.toIso8601String(),
      'updated_at': following.updatedAt.toIso8601String(),
    };
    
    return await db.insert('following', followingData);
  }

  Future<List<InstagramUser>> getFollowing(int accountId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'following',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'following_at DESC',
    );
    return List.generate(maps.length, (i) {
      final map = maps[i];
      // Convert integer values back to booleans for SQLite compatibility
      map['is_verified'] = map['is_verified'] == 1;
      map['is_private'] = map['is_private'] == 1;
      map['is_business'] = map['is_business'] == 1;
      return InstagramUser.fromJson(map);
    });
  }

  Future<InstagramUser?> getFollowingByUsername(int accountId, String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'following',
      where: 'account_id = ? AND username = ?',
      whereArgs: [accountId, username],
    );
    if (maps.isNotEmpty) {
      final map = maps.first;
      // Convert integer values back to booleans for SQLite compatibility
      map['is_verified'] = map['is_verified'] == 1;
      map['is_private'] = map['is_private'] == 1;
      map['is_business'] = map['is_business'] == 1;
      return InstagramUser.fromJson(map);
    }
    return null;
  }

  Future<int> updateFollowing(InstagramUser following, int accountId) async {
    final db = await database;
    
    // Create a clean data map with only the fields we need for the database
    final followingData = {
      'account_id': accountId,
      'username': following.username,
      'full_name': following.fullName,
      'profile_picture_url': following.profilePictureUrl,
      'is_verified': following.isVerified ? 1 : 0,
      'is_private': following.isPrivate ? 1 : 0,
      'is_business': following.isBusiness ? 1 : 0,
      'external_url': following.externalUrl,
      'followers_count': following.followersCount,
      'following_count': following.followingCount,
      'posts_count': following.postsCount,
      'biography': following.biography,
      'following_at': following.followingAt?.toIso8601String(),
      'last_seen': following.lastSeen?.toIso8601String(),
      'created_at': following.createdAt.toIso8601String(),
      'updated_at': following.updatedAt.toIso8601String(),
    };
    
    return await db.update(
      'following',
      followingData,
      where: 'account_id = ? AND username = ?',
      whereArgs: [accountId, following.username],
    );
  }

  Future<int> deleteFollowing(int accountId, String username) async {
    final db = await database;
    return await db.delete(
      'following',
      where: 'account_id = ? AND username = ?',
      whereArgs: [accountId, username],
    );
  }

  // Sync queue operations
  Future<int> addToSyncQueue(int accountId, String operationType, String targetUsername, String action) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.insert('sync_queue', {
      'account_id': accountId,
      'operation_type': operationType,
      'target_username': targetUsername,
      'action': action,
      'status': 'pending',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncOperations() async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
  }

  Future<int> updateSyncOperationStatus(int id, String status) async {
    final db = await database;
    return await db.update(
      'sync_queue',
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSyncOperation(int id) async {
    final db = await database;
    return await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Utility methods
  Future<void> clearAccountData(int accountId) async {
    final db = await database;
    await db.delete('followers', where: 'account_id = ?', whereArgs: [accountId]);
    await db.delete('following', where: 'account_id = ?', whereArgs: [accountId]);
    await db.delete('sync_queue', where: 'account_id = ?', whereArgs: [accountId]);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
