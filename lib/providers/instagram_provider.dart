import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/instagram_account.dart';
import '../models/instagram_user.dart';
import '../models/profile.dart';
import '../services/instagram_api_service.dart';
import '../services/sync_service.dart';

class InstagramProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final InstagramApiService _apiService = InstagramApiService();
  final SyncService _syncService = SyncService();

  List<InstagramAccount> _accounts = [];
  List<InstagramUser> _followers = [];
  List<InstagramUser> _following = [];
  Profile? _currentProfile;
  InstagramAccount? _currentAccount;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _twoFactorInfo;

  // Getters
  List<InstagramAccount> get accounts => _accounts;
  List<InstagramUser> get followers => _followers;
  List<InstagramUser> get following => _following;
  Profile? get currentProfile => _currentProfile;
  InstagramAccount? get currentAccount => _currentAccount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Map<String, dynamic>? getTwoFactorInfo() => _twoFactorInfo;

  // Initialize provider
  Future<void> initialize() async {
    _apiService.initialize();
    await _loadAccounts();
    await _syncService.initialize();
  }

  // Load all accounts
  Future<void> _loadAccounts() async {
    try {
      _accounts = await _dbHelper.getAllInstagramAccounts();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load accounts: $e';
      notifyListeners();
    }
  }

  // Add new account
  Future<bool> addAccount(String username, String password) async {
    _setLoading(true);
    _clearError();

    try {
      // Attempt to login
      final account = await _apiService.login(username, password);
      
      if (account != null) {
        // Save account to database
        final accountId = await _dbHelper.insertInstagramAccount(account);
        final savedAccount = account.copyWith(id: accountId);
        
        _accounts.add(savedAccount);
        notifyListeners();
        
        // Start initial sync
        await _syncAccount(savedAccount);
        
        return true;
      } else {
        _error = 'Login failed. Please check your credentials.';
        return false;
      }
    } on TwoFactorRequiredException catch (e) {
      _error = e.message;
      if (kDebugMode) {
        print('2FA required: ${e.message}');
        print('2FA info: ${e.twoFactorInfo}');
      }
      _twoFactorInfo = e.twoFactorInfo;
      return false;
    } catch (e) {
      _error = 'Login error: $e';
      if (kDebugMode) {
        print('Login error: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Add account with 2FA
  Future<bool> addAccountWith2FA(String username, String password, String twoFactorCode) async {
    _setLoading(true);
    _clearError();

    try {
      // Attempt to login with 2FA
      final account = await _apiService.loginWith2FA(username, password, twoFactorCode);
      
      if (account != null) {
        // Save account to database
        final accountId = await _dbHelper.insertInstagramAccount(account);
        final savedAccount = account.copyWith(id: accountId);
        
        _accounts.add(savedAccount);
        notifyListeners();
        
        // Start initial sync
        await _syncAccount(savedAccount);
        
        return true;
      } else {
        _error = '2FA verification failed. Please check your code.';
        return false;
      }
    } catch (e) {
      _error = '2FA login error: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Select account
  Future<void> selectAccount(InstagramAccount account) async {
    _currentAccount = account;
    _setLoading(true);
    _clearError();

    try {
      if (kDebugMode) {
        print('[Provider] Loading account data for: ${account.username}');
        print('[Provider] Account ID: ${account.id}');
      }
      
      // Load profile data
      _currentProfile = await _dbHelper.getProfileByUsername(account.username);
      if (kDebugMode) {
        print('[Provider] Profile loaded: ${_currentProfile?.username}');
      }
      
      // Load followers and following
      _followers = await _dbHelper.getFollowers(account.id!);
      if (kDebugMode) {
        print('[Provider] Followers loaded: ${_followers.length}');
      }
      
      _following = await _dbHelper.getFollowing(account.id!);
      if (kDebugMode) {
        print('[Provider] Following loaded: ${_following.length}');
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('[Provider] Error loading account data: $e');
        print('[Provider] Error type: ${e.runtimeType}');
      }
      
      // If it's a read-only error, try to reopen the database
      if (e.toString().contains('read-only')) {
        if (kDebugMode) {
          print('[Provider] Attempting to reopen database...');
        }
        try {
          await _dbHelper.reopen();
          // Retry loading the data
          _currentProfile = await _dbHelper.getProfileByUsername(account.username);
          _followers = await _dbHelper.getFollowers(account.id!);
          _following = await _dbHelper.getFollowing(account.id!);
          notifyListeners();
          return;
        } catch (retryError) {
          if (kDebugMode) {
            print('[Provider] Retry failed: $retryError');
            print('[Provider] Attempting to recreate database...');
          }
          try {
            await _dbHelper.recreateDatabase();
            // Retry loading the data after recreation
            _currentProfile = await _dbHelper.getProfileByUsername(account.username);
            _followers = await _dbHelper.getFollowers(account.id!);
            _following = await _dbHelper.getFollowing(account.id!);
            notifyListeners();
            return;
          } catch (recreateError) {
            if (kDebugMode) {
              print('[Provider] Database recreation failed: $recreateError');
            }
            _error = 'Failed to load account data: $recreateError';
          }
        }
      } else {
        _error = 'Failed to load account data: $e';
      }
    } finally {
      _setLoading(false);
    }
  }

  // Sync account data
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
      
      // Reload data if this is the current account
      if (_currentAccount?.id == account.id) {
        await selectAccount(account);
      }
    } catch (e) {
      _error = 'Sync error: $e';
      notifyListeners();
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
      const int maxTotal = 10000; // Limit to prevent excessive API calls

      do {
        final response = await _apiService.getFollowers(account.username, maxId: maxId, password: account.password);
        final followers = response.users;
        
        if (kDebugMode) {
          print('[Provider] Fetched ${followers.length} followers for ${account.username}. Next maxId: ${response.nextMaxId}');
        }
        
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
        maxId = response.nextMaxId;

        // Break if we've reached the limit or no more data
        if (maxId == null || totalSynced >= maxTotal) {
          break;
        }

        // Add delay to avoid rate limiting
        await Future.delayed(const Duration(seconds: 2));

           } while (totalSynced < maxTotal);

    } catch (e) {
      // Error syncing followers: $e
    }
  }

  // Sync following
  Future<void> _syncFollowing(InstagramAccount account) async {
    try {
      if (kDebugMode) {
        print('[Provider] Starting sync following for ${account.username}');
      }
      
      String? maxId;
      int totalSynced = 0;
      const int maxTotal = 10000; // Limit to prevent excessive API calls

      do {
        if (kDebugMode) {
          print('[Provider] Fetching following batch ${totalSynced ~/ 200 + 1} for ${account.username}');
        }
        
        final response = await _apiService.getFollowing(account.username, maxId: maxId, password: account.password);
        final following = response.users;
        
        if (kDebugMode) {
          print('[Provider] Fetched ${following.length} following for ${account.username}. Next maxId: ${response.nextMaxId}');
        }
        
        if (following.isEmpty) {
          if (kDebugMode) {
            print('[Provider] No more following to sync for ${account.username}');
          }
          break;
        }

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
        maxId = response.nextMaxId;

        if (kDebugMode) {
          print('[Provider] Total synced so far: $totalSynced, nextMaxId: $maxId');
        }

        // Break if we've reached the limit or no more data
        if (maxId == null || totalSynced >= maxTotal) {
          if (kDebugMode) {
            print('[Provider] Stopping sync following for ${account.username}. Reason: ${maxId == null ? "no more data" : "reached limit"}');
          }
          break;
        }

        // Add delay to avoid rate limiting
        if (kDebugMode) {
          print('[Provider] Waiting 2 seconds before next batch...');
        }
        await Future.delayed(const Duration(seconds: 2));

           } while (totalSynced < maxTotal);

      if (kDebugMode) {
        print('[Provider] Completed sync following for ${account.username}. Total synced: $totalSynced');
      }

    } catch (e) {
      if (kDebugMode) {
        print('[Provider] Error syncing following for ${account.username}: $e');
      }
    }
  }

  // Manual sync
  Future<void> performSync() async {
    if (_currentAccount == null) {
      if (kDebugMode) {
        print('[Provider] No current account selected for sync');
      }
      return;
    }
    
    if (kDebugMode) {
      print('[Provider] Starting manual sync for ${_currentAccount!.username}');
    }
    
    _setLoading(true);
    _clearError();

    try {
      await _syncService.performManualSync();
      
      if (kDebugMode) {
        print('[Provider] Manual sync completed, reloading account data');
      }
      
      // Reload current account data
      await selectAccount(_currentAccount!);
      
      if (kDebugMode) {
        print('[Provider] Account data reloaded. Followers: ${_followers.length}, Following: ${_following.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[Provider] Manual sync failed: $e');
      }
      _error = 'Sync failed: $e';
    } finally {
      _setLoading(false);
    }
  }

  // Add follower locally
  Future<void> addFollower(InstagramUser user) async {
    if (_currentAccount == null) return;

    try {
      final newFollower = user.copyWith(
        followedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _dbHelper.insertFollower(newFollower, _currentAccount!.id!);
      _followers.add(newFollower);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to add follower: $e';
      notifyListeners();
    }
  }

  // Remove follower locally
  Future<void> removeFollower(String username) async {
    if (_currentAccount == null) return;

    try {
      await _dbHelper.deleteFollower(_currentAccount!.id!, username);
      _followers.removeWhere((f) => f.username == username);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to remove follower: $e';
      notifyListeners();
    }
  }

  // Add following locally
  Future<void> addFollowing(InstagramUser user) async {
    if (_currentAccount == null) return;

    try {
      final newFollowing = user.copyWith(
        followingAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _dbHelper.insertFollowing(newFollowing, _currentAccount!.id!);
      _following.add(newFollowing);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to add following: $e';
      notifyListeners();
    }
  }

  // Remove following locally
  Future<void> removeFollowing(String username) async {
    if (_currentAccount == null) return;

    try {
      await _dbHelper.deleteFollowing(_currentAccount!.id!, username);
      _following.removeWhere((f) => f.username == username);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to remove following: $e';
      notifyListeners();
    }
  }

  // Queue follow action for sync
  Future<void> queueFollowAction(String username) async {
    if (_currentAccount == null) return;

    try {
      await _syncService.addToSyncQueue(
        _currentAccount!.id!,
        'follow',
        username,
        'add',
      );
    } catch (e) {
      _error = 'Failed to queue follow action: $e';
      notifyListeners();
    }
  }

  // Queue unfollow action for sync
  Future<void> queueUnfollowAction(String username) async {
    if (_currentAccount == null) return;

    try {
      await _syncService.addToSyncQueue(
        _currentAccount!.id!,
        'follow',
        username,
        'remove',
      );
    } catch (e) {
      _error = 'Failed to queue unfollow action: $e';
      notifyListeners();
    }
  }

  // Delete account
  Future<void> deleteAccount(InstagramAccount account) async {
    try {
      await _dbHelper.deleteInstagramAccount(account.id!);
      _accounts.removeWhere((a) => a.id == account.id);
      
      if (_currentAccount?.id == account.id) {
        _currentAccount = null;
        _currentProfile = null;
        _followers.clear();
        _following.clear();
      }
      
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete account: $e';
      notifyListeners();
    }
  }

  // Logout account (clear session but keep account data)
  Future<void> logoutAccount(InstagramAccount account) async {
    try {
      if (kDebugMode) {
        print('[Provider] Logging out account: ${account.username}');
      }
      
      // Clear the session by updating the account with null session data
      final updatedAccount = account.copyWith(
        sessionId: null,
        csrfToken: null,
        lastSync: null,
        updatedAt: DateTime.now(),
      );
      
      await _dbHelper.updateInstagramAccount(updatedAccount);
      
      // Update the account in our local list
      final index = _accounts.indexWhere((a) => a.id == account.id);
      if (index != -1) {
        _accounts[index] = updatedAccount;
      }
      
      // If this is the current account, clear the current data
      if (_currentAccount?.id == account.id) {
        _currentAccount = updatedAccount;
        _currentProfile = null;
        _followers.clear();
        _following.clear();
      }
      
      if (kDebugMode) {
        print('[Provider] Account logged out successfully: ${account.username}');
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('[Provider] Error logging out account: $e');
      }
      _error = 'Failed to logout account: $e';
      notifyListeners();
    }
  }

  // Search followers
  List<InstagramUser> searchFollowers(String query) {
    if (query.isEmpty) return _followers;
    
    return _followers.where((follower) {
      return follower.username.toLowerCase().contains(query.toLowerCase()) ||
             (follower.fullName?.toLowerCase().contains(query.toLowerCase()) ?? false);
    }).toList();
  }

  // Search following
  List<InstagramUser> searchFollowing(String query) {
    if (query.isEmpty) return _following;
    
    return _following.where((user) {
      return user.username.toLowerCase().contains(query.toLowerCase()) ||
             (user.fullName?.toLowerCase().contains(query.toLowerCase()) ?? false);
    }).toList();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  // Start background sync
  Future<void> startBackgroundSync() async {
    await _syncService.scheduleBackgroundSync();
  }

  // Stop background sync
  Future<void> stopBackgroundSync() async {
    await _syncService.cancelBackgroundSync();
  }
}
