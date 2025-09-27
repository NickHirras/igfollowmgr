import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/instagram_account.dart';
import '../models/instagram_user.dart';
import '../models/profile.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'igfollowmgr.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Instagram Accounts table
    await db.execute('''
      CREATE TABLE instagram_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT,
        session_id TEXT,
        csrf_token TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        last_login TEXT,
        last_sync TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
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

  // Instagram Account CRUD operations
  Future<int> insertInstagramAccount(InstagramAccount account) async {
    final db = await database;
    return await db.insert('instagram_accounts', account.toJson());
  }

  Future<List<InstagramAccount>> getAllInstagramAccounts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('instagram_accounts');
    return List.generate(maps.length, (i) => InstagramAccount.fromJson(maps[i]));
  }

  Future<InstagramAccount?> getInstagramAccountByUsername(String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'instagram_accounts',
      where: 'username = ?',
      whereArgs: [username],
    );
    if (maps.isNotEmpty) {
      return InstagramAccount.fromJson(maps.first);
    }
    return null;
  }

  Future<int> updateInstagramAccount(InstagramAccount account) async {
    final db = await database;
    return await db.update(
      'instagram_accounts',
      account.toJson(),
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
    final followerData = follower.toJson();
    followerData['account_id'] = accountId;
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
    return List.generate(maps.length, (i) => InstagramUser.fromJson(maps[i]));
  }

  Future<InstagramUser?> getFollowerByUsername(int accountId, String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'followers',
      where: 'account_id = ? AND username = ?',
      whereArgs: [accountId, username],
    );
    if (maps.isNotEmpty) {
      return InstagramUser.fromJson(maps.first);
    }
    return null;
  }

  Future<int> updateFollower(InstagramUser follower, int accountId) async {
    final db = await database;
    final followerData = follower.toJson();
    followerData['account_id'] = accountId;
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
    final followingData = following.toJson();
    followingData['account_id'] = accountId;
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
    return List.generate(maps.length, (i) => InstagramUser.fromJson(maps[i]));
  }

  Future<InstagramUser?> getFollowingByUsername(int accountId, String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'following',
      where: 'account_id = ? AND username = ?',
      whereArgs: [accountId, username],
    );
    if (maps.isNotEmpty) {
      return InstagramUser.fromJson(maps.first);
    }
    return null;
  }

  Future<int> updateFollowing(InstagramUser following, int accountId) async {
    final db = await database;
    final followingData = following.toJson();
    followingData['account_id'] = accountId;
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
