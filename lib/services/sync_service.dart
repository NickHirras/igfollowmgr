import 'dart:async';
import 'package:workmanager/workmanager.dart';
import '../database/database_helper.dart';
import '../models/instagram_account.dart';
import 'instagram_api_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final InstagramApiService _apiService = InstagramApiService();
  Timer? _syncTimer;
  bool _isSyncing = false;

  // Initialize the sync service
  Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  // Start periodic sync
  void startPeriodicSync({Duration interval = const Duration(minutes: 30)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) => _performSync());
  }

  // Stop periodic sync
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  // Perform manual sync
  Future<void> performManualSync() async {
    await _performSync();
  }

  // Main sync method
  Future<void> _performSync() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    
    try {
      final accounts = await _dbHelper.getAllInstagramAccounts();
      
      for (final account in accounts) {
        if (account.isActive) {
          await _syncAccount(account);
        }
      }
      
      // Process sync queue
      await _processSyncQueue();
      
    } catch (e) {
      // Sync error: $e
    } finally {
      _isSyncing = false;
    }
  }

  // Sync a specific account
  Future<void> _syncAccount(InstagramAccount account) async {
    try {
      // Set up API session
      if (account.sessionId != null && account.csrfToken != null) {
        _apiService.setSession(account.sessionId!, account.csrfToken!);
      }

      // Sync profile data
      await _syncProfileData(account);

      // Sync followers
      await _syncFollowers(account);

      // Sync following
      await _syncFollowing(account);

      // Update last sync time
      final updatedAccount = account.copyWith(
        lastSync: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _dbHelper.updateInstagramAccount(updatedAccount);

    } catch (e) {
      // Error syncing account ${account.username}: $e
    }
  }

  // Sync profile data
  Future<void> _syncProfileData(InstagramAccount account) async {
    try {
      final profile = await _apiService.getUserProfile(account.username);
      if (profile != null) {
        final existingProfile = await _dbHelper.getProfileByUsername(account.username);
        
        if (existingProfile != null) {
          final updatedProfile = profile.copyWith(
            id: existingProfile.id,
            createdAt: existingProfile.createdAt,
            updatedAt: DateTime.now(),
          );
          await _dbHelper.updateProfile(updatedProfile);
        } else {
          await _dbHelper.insertProfile(profile);
        }
      }
    } catch (e) {
      // Error syncing profile data: $e
    }
  }

  // Sync followers
  Future<void> _syncFollowers(InstagramAccount account) async {
    try {
      String? maxId;
      int totalSynced = 0;
      const int maxPerRequest = 200;
      const int maxTotal = 10000; // Limit to prevent excessive API calls

      do {
        final followers = await _apiService.getFollowers(account.username, maxId: maxId);
        
        if (followers.isEmpty) break;

        for (final follower in followers) {
          final existingFollower = await _dbHelper.getFollowerByUsername(account.id!, follower.username);
          
          if (existingFollower != null) {
            // Update existing follower
            final updatedFollower = follower.copyWith(
              id: existingFollower.id,
              followedAt: existingFollower.followedAt,
              createdAt: existingFollower.createdAt,
              updatedAt: DateTime.now(),
            );
            await _dbHelper.updateFollower(updatedFollower, account.id!);
          } else {
            // Add new follower
            final newFollower = follower.copyWith(
              followedAt: DateTime.now(), // Approximate time
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await _dbHelper.insertFollower(newFollower, account.id!);
          }
        }

        totalSynced += followers.length;
        maxId = followers.isNotEmpty ? followers.last.username : null;

        // Break if we've reached the limit or no more data
        if (followers.length < maxPerRequest || totalSynced >= maxTotal) {
          break;
        }

        // Add delay to avoid rate limiting
        await Future.delayed(const Duration(seconds: 2));

      } while (maxId != null && totalSynced < maxTotal);

    } catch (e) {
      // Error syncing followers: $e
    }
  }

  // Sync following
  Future<void> _syncFollowing(InstagramAccount account) async {
    try {
      String? maxId;
      int totalSynced = 0;
      const int maxPerRequest = 200;
      const int maxTotal = 10000; // Limit to prevent excessive API calls

      do {
        final following = await _apiService.getFollowing(account.username, maxId: maxId);
        
        if (following.isEmpty) break;

        for (final user in following) {
          final existingFollowing = await _dbHelper.getFollowingByUsername(account.id!, user.username);
          
          if (existingFollowing != null) {
            // Update existing following
            final updatedFollowing = user.copyWith(
              id: existingFollowing.id,
              followingAt: existingFollowing.followingAt,
              createdAt: existingFollowing.createdAt,
              updatedAt: DateTime.now(),
            );
            await _dbHelper.updateFollowing(updatedFollowing, account.id!);
          } else {
            // Add new following
            final newFollowing = user.copyWith(
              followingAt: DateTime.now(), // Approximate time
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await _dbHelper.insertFollowing(newFollowing, account.id!);
          }
        }

        totalSynced += following.length;
        maxId = following.isNotEmpty ? following.last.username : null;

        // Break if we've reached the limit or no more data
        if (following.length < maxPerRequest || totalSynced >= maxTotal) {
          break;
        }

        // Add delay to avoid rate limiting
        await Future.delayed(const Duration(seconds: 2));

      } while (maxId != null && totalSynced < maxTotal);

    } catch (e) {
      // Error syncing following: $e
    }
  }

  // Process sync queue
  Future<void> _processSyncQueue() async {
    try {
      final pendingOperations = await _dbHelper.getPendingSyncOperations();
      
      for (final operation in pendingOperations) {
        await _processSyncOperation(operation);
      }
    } catch (e) {
      // Error processing sync queue: $e
    }
  }

  // Process individual sync operation
  Future<void> _processSyncOperation(Map<String, dynamic> operation) async {
    try {
      final accountId = operation['account_id'] as int;
      final operationType = operation['operation_id'] as String;
      final targetUsername = operation['target_username'] as String;
      final action = operation['action'] as String;
      final operationId = operation['id'] as int;

      // Get account details
      final accounts = await _dbHelper.getAllInstagramAccounts();
      final account = accounts.firstWhere((a) => a.id == accountId);

      if (account.sessionId != null && account.csrfToken != null) {
        _apiService.setSession(account.sessionId!, account.csrfToken!);
      }

      bool success = false;

      if (operationType == 'follow' && action == 'add') {
        // Follow user
        success = await _apiService.followUser(targetUsername);
      } else if (operationType == 'follow' && action == 'remove') {
        // Unfollow user
        success = await _apiService.unfollowUser(targetUsername);
      }

      if (success) {
        await _dbHelper.updateSyncOperationStatus(operationId, 'completed');
        await _dbHelper.deleteSyncOperation(operationId);
      } else {
        await _dbHelper.updateSyncOperationStatus(operationId, 'failed');
      }

    } catch (e) {
      // Error processing sync operation: $e
      await _dbHelper.updateSyncOperationStatus(operation['id'], 'failed');
    }
  }

  // Add operation to sync queue
  Future<void> addToSyncQueue(int accountId, String operationType, String targetUsername, String action) async {
    await _dbHelper.addToSyncQueue(accountId, operationType, targetUsername, action);
  }

  // Schedule background sync
  Future<void> scheduleBackgroundSync() async {
    await Workmanager().registerPeriodicTask(
      "sync_task",
      "sync_instagram_data",
      frequency: const Duration(minutes: 30),
    );
  }

  // Cancel background sync
  Future<void> cancelBackgroundSync() async {
    await Workmanager().cancelByUniqueName("sync_task");
  }
}

// Background task callback
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final syncService = SyncService();
    await syncService._performSync();
    return Future.value(true);
  });
}
