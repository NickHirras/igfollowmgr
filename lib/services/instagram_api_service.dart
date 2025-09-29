import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/instagram_account.dart';
import '../models/profile.dart';
import '../models/followers_response.dart';

// Custom exception for 2FA requirement
class TwoFactorRequiredException implements Exception {
  final dynamic twoFactorInfo;
  final String message;
  
  TwoFactorRequiredException({
    required this.twoFactorInfo,
    required this.message,
  });
  
  @override
  String toString() => message;
}

class InstagramApiService {
  static final InstagramApiService _instance = InstagramApiService._internal();
  factory InstagramApiService() => _instance;
  InstagramApiService._internal();

  final Dio _dio = Dio();
  static const String _baseUrl = 'https://www.instagram.com';
  String? _csrfToken;
  String? _rolloutHash;
  DateTime? _lastSMSRequest;
  DateTime? _lastSessionCheck;

  // Initialize the service
  void initialize() {
    _dio.options.baseUrl = _baseUrl;
    // Use a custom cookie interceptor that can handle malformed cookies
    _dio.interceptors.add(_CustomCookieInterceptor());
    // Note: Brotli compression is handled automatically by Dio
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate',
      'DNT': '1',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Sec-Ch-Ua': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
      'Sec-Ch-Ua-Mobile': '?0',
      'Sec-Ch-Ua-Platform': '"Windows"',
    };
  }

  // Login to Instagram
  Future<InstagramAccount?> login(String username, String password) async {
    return await _performLogin(username, password, null);
  }

  // Login with 2FA code
  Future<InstagramAccount?> loginWith2FA(String username, String password, String twoFactorCode) async {
    return await _performLogin(username, password, twoFactorCode);
  }

  // Internal login method that handles both regular and 2FA login
  Future<InstagramAccount?> _performLogin(String username, String password, String? twoFactorCode) async {
    try {
      // First, get the login page to extract CSRF token and other required data
      final csrfToken = await getCsrfToken();
      
      if (kDebugMode) {
        print('Successfully extracted CSRF token: ${csrfToken.substring(0, 10)}...');
      }

      // Add a small delay to make requests look more human-like
      await Future.delayed(Duration(milliseconds: 500 + (DateTime.now().millisecondsSinceEpoch % 1000)));

      // Prepare login data in the exact format Instagram expects
      final loginData = {
        'username': username,
        'enc_password': '#PWD_INSTAGRAM_BROWSER:0:${DateTime.now().millisecondsSinceEpoch}:$password',
        'queryParams': '{}',
        'optIntoOneTap': 'false',
        'trustedDeviceRecords': '{}',
        'rollout_hash': _rolloutHash ?? '',
      };

      // Set up headers for login - these must match exactly what the web interface sends
      final loginHeaders = {
        'X-CSRFToken': csrfToken,
        'X-Requested-With': 'XMLHttpRequest',
        'X-Instagram-AJAX': '1',
        'X-ASBD-ID': '129477',
        'X-IG-App-ID': '936619743392459',
        'X-IG-WWW-Claim': '0',
        'Referer': 'https://www.instagram.com/accounts/login/',
        'Origin': 'https://www.instagram.com',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-origin',
        'Sec-Ch-Ua': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
        'Sec-Ch-Ua-Mobile': '?0',
        'Sec-Ch-Ua-Platform': '"Windows"',
      };

      // Perform login
      final loginResponse = await _dio.post(
        '/api/v1/web/accounts/login/ajax/',
        data: loginData,
        options: Options(
          headers: loginHeaders,
          contentType: 'application/x-www-form-urlencoded',
          validateStatus: (status) => status! < 500, // Accept 4xx status codes
        ),
      );

      if (loginResponse.statusCode == 200) {
        final responseData = loginResponse.data;
        
        if (kDebugMode) {
          print('Login response data: $responseData');
        }
        
        // Check if 2FA is required - Instagram uses different response formats
        final is2FARequired = responseData['two_factor_required'] == true || 
                             responseData['two_factor_info'] != null ||
                             responseData['checkpoint_url'] != null ||
                             responseData['challenge'] != null ||
                             (responseData['message'] != null && 
                              (responseData['message'].toString().toLowerCase().contains('two-factor') ||
                               responseData['message'].toString().toLowerCase().contains('verification code') ||
                               responseData['message'].toString().toLowerCase().contains('2fa'))) ||
                             responseData['status'] == 'fail' && 
                             responseData['message'] != null &&
                             responseData['message'].toString().toLowerCase().contains('verification');
        
        if (is2FARequired) {
          if (twoFactorCode == null) {
            if (kDebugMode) {
              print('2FA required. Response data: $responseData');
            }
            // Automatically request SMS code to be sent
            try {
              final twoFactorIdentifier = responseData['two_factor_info']?['two_factor_identifier'];
              if (twoFactorIdentifier != null) {
                if (kDebugMode) {
                  print('Requesting 2FA SMS for identifier: $twoFactorIdentifier');
                }
                await request2FASMS(username, twoFactorIdentifier);
              }
            } catch (e) {
              if (kDebugMode) {
                print('Failed to automatically request 2FA SMS: $e');
              }
              // Don't block the user, they can still enter a code from an authenticator app
            }
            throw TwoFactorRequiredException(
              twoFactorInfo: responseData['two_factor_info'] ?? responseData,
              message: 'Two-factor authentication is required. An SMS has been sent to your phone.',
            );
          } else {
            // Handle 2FA challenge
            return await _handleTwoFactorChallenge(username, password, csrfToken, twoFactorCode, responseData);
          }
        }
        
        if (responseData['authenticated'] == true) {
          // Extract session cookies
          final cookies = _extractCookies(loginResponse.headers);
          final sessionId = cookies['sessionid'];
          
          if (sessionId != null) {
            // Create account object
            final account = InstagramAccount(
              username: username,
              password: password, // In production, encrypt this
              sessionId: sessionId,
              csrfToken: csrfToken,
              isActive: true,
              lastLogin: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            return account;
          } else {
            throw Exception('Failed to extract session ID from login response');
          }
        } else {
          final errorMessage = responseData['message'] ?? responseData['error_type'] ?? 'Authentication failed';
          throw Exception('Login failed: $errorMessage');
        }
      } else if (loginResponse.statusCode == 400) {
        final responseData = loginResponse.data;
        final errorMessage = responseData['message'] ?? responseData['error_type'] ?? 'Bad request';
        
        if (kDebugMode) {
          print('400 Error response: $responseData');
        }
        
        // Check if this might be a 2FA requirement disguised as a 400 error
        final mightBe2FA = responseData['two_factor_required'] == true || 
                          responseData['two_factor_info'] != null ||
                          responseData['checkpoint_url'] != null ||
                          responseData['challenge'] != null ||
                          (errorMessage.toString().toLowerCase().contains('verification')) ||
                          (errorMessage.toString().toLowerCase().contains('two-factor')) ||
                          (errorMessage.toString().toLowerCase().contains('2fa'));
        
        if (mightBe2FA && twoFactorCode == null) {
          if (kDebugMode) {
            print('400 error might be 2FA requirement. Requesting SMS.');
          }
          // Automatically request SMS code to be sent
          try {
            final twoFactorIdentifier = responseData['two_factor_info']?['two_factor_identifier'];
            if (twoFactorIdentifier != null) {
              if (kDebugMode) {
                print('Requesting 2FA SMS for identifier: $twoFactorIdentifier');
              }
              await request2FASMS(username, twoFactorIdentifier);
            }
          } catch (e) {
            if (kDebugMode) {
              print('Failed to automatically request 2FA SMS from 400 error: $e');
            }
            // Don't block the user, they can still enter a code from an authenticator app
          }
          throw TwoFactorRequiredException(
            twoFactorInfo: responseData,
            message: 'Two-factor authentication may be required. An SMS has been sent to your phone.',
          );
        }
        
        throw Exception('Login failed (400): $errorMessage');
      } else {
        throw Exception('Login request failed with status: ${loginResponse.statusCode}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timeout. Please check your internet connection.');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Request timeout. Please try again.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Connection error. Please check your internet connection.');
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  // Get user profile information
  Future<Profile?> getUserProfile(String username) async {
    try {
      final response = await _dio.get('/$username/');
      
      if (response.statusCode == 200) {
        final profileData = _extractProfileData(response.data);
        if (profileData != null) {
          return Profile.fromJson(profileData);
        }
      }
      
      return null;
    } catch (e) {
      throw Exception('Failed to get profile: $e');
    }
  }

  // Get followers list
  Future<FollowersResponse> getFollowers(String username, {String? maxId, String? password}) async {
    try {
      // First get the user ID
      final userId = await getUserId(username, password: password);
      if (userId == null) {
        throw Exception('Failed to get user ID for $username');
      }

      final url = '/api/v1/friendships/$userId/followers/';
      final queryParams = <String, dynamic>{
        'count': '200',
        'search_surface': 'follow_list_page',
        'enable_groups': 'true',
      };
      
      if (maxId != null) {
        queryParams['max_id'] = maxId;
      }

      if (kDebugMode) {
        print('[API] Getting followers for $username (ID: $userId) with maxId: $maxId');
        print('[API] Request URL: $url');
        print('[API] Query params: $queryParams');
      }

      final response = await _dio.get(
        url, 
        queryParameters: queryParams,
        options: Options(
          headers: {
            'X-IG-App-ID': '936619743392459',
            'X-IG-WWW-Claim': '0',
            'X-Requested-With': 'XMLHttpRequest',
            'X-Instagram-AJAX': '1',
            'X-ASBD-ID': '129477',
            'Referer': 'https://www.instagram.com/',
            'Accept': '*/*',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
            'Sec-Fetch-Dest': 'empty',
            'Sec-Fetch-Mode': 'cors',
            'Sec-Fetch-Site': 'same-origin',
            'Sec-Ch-Ua': '"Not_A Brand";v="8", "Chromium";v="131", "Google Chrome";v="131"',
            'Sec-Ch-Ua-Mobile': '?0',
            'Sec-Ch-Ua-Platform': '"Windows"',
          },
        ),
      );
      
      if (kDebugMode) {
        print('[API] Followers response status: ${response.statusCode}');
        print('[API] Followers response data: ${response.data}');
      }
      
      if (response.statusCode == 200) {
        final result = FollowersResponse.fromJson(response.data);
        if (kDebugMode) {
          print('[API] Parsed followers response: ${result.users.length} users, nextMaxId: ${result.nextMaxId}');
        }
        return result;
      }
      
      if (kDebugMode) {
        print('[API] Followers request failed with status: ${response.statusCode}');
      }
      return FollowersResponse(users: [], nextMaxId: null);
    } catch (e) {
      if (kDebugMode) {
        print('[API] Followers request error: $e');
      }
      throw Exception('Failed to get followers: $e');
    }
  }

  // Get following list
  Future<FollowersResponse> getFollowing(String username, {String? maxId, String? password}) async {
    try {
      // First get the user ID
      final userId = await getUserId(username, password: password);
      if (userId == null) {
        throw Exception('Failed to get user ID for $username');
      }

      final url = '/api/v1/friendships/$userId/following/';
      final queryParams = <String, dynamic>{
        'count': '200',
        'search_surface': 'follow_list_page',
        'enable_groups': 'true',
      };
      
      if (maxId != null) {
        queryParams['max_id'] = maxId;
      }

      if (kDebugMode) {
        print('[API] Getting following for $username (ID: $userId) with maxId: $maxId');
        print('[API] Request URL: $url');
        print('[API] Query params: $queryParams');
      }

      final response = await _dio.get(
        url, 
        queryParameters: queryParams,
        options: Options(
          headers: {
            'X-IG-App-ID': '936619743392459',
            'X-IG-WWW-Claim': '0',
            'X-Requested-With': 'XMLHttpRequest',
            'X-Instagram-AJAX': '1',
            'X-ASBD-ID': '129477',
            'Referer': 'https://www.instagram.com/',
            'Accept': '*/*',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
            'Sec-Fetch-Dest': 'empty',
            'Sec-Fetch-Mode': 'cors',
            'Sec-Fetch-Site': 'same-origin',
            'Sec-Ch-Ua': '"Not_A Brand";v="8", "Chromium";v="131", "Google Chrome";v="131"',
            'Sec-Ch-Ua-Mobile': '?0',
            'Sec-Ch-Ua-Platform': '"Windows"',
          },
        ),
      );
      
      if (kDebugMode) {
        print('[API] Following response status: ${response.statusCode}');
        print('[API] Following response data: ${response.data}');
      }
      
      if (response.statusCode == 200) {
        final result = FollowersResponse.fromJson(response.data);
        if (kDebugMode) {
          print('[API] Parsed following response: ${result.users.length} users, nextMaxId: ${result.nextMaxId}');
        }
        return result;
      }
      
      if (kDebugMode) {
        print('[API] Following request failed with status: ${response.statusCode}');
      }
      return FollowersResponse(users: [], nextMaxId: null);
    } catch (e) {
      if (kDebugMode) {
        print('[API] Following request error: $e');
      }
      throw Exception('Failed to get following: $e');
    }
  }

  // Get user ID from username
  Future<String?> getUserId(String username, {String? password}) async {
    try {
      if (kDebugMode) {
        print('[API] Getting user ID for $username');
      }

      // Ensure we have a valid session if password is provided
      if (password != null) {
        final sessionValid = await ensureValidSession(username, password);
        if (!sessionValid) {
          if (kDebugMode) {
            print('[API] Failed to ensure valid session for $username');
          }
          throw Exception('Session expired, please re-login');
        }
      }
      
      final response = await _dio.get(
        '/api/v1/users/web_profile_info/',
        queryParameters: {'username': username},
        options: Options(
          headers: {
            'X-IG-App-ID': '936619743392459',
          },
        ),
      );

      if (kDebugMode) {
        print('[API] User ID response status: ${response.statusCode}');
        print('[API] User ID response data: ${response.data}');
      }

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['data'] != null && data['data']['user'] != null) {
          final userId = data['data']['user']['id'];
          if (kDebugMode) {
            print('[API] Found user ID: $userId for $username');
          }
          return userId;
        }
      }
      
      if (kDebugMode) {
        print('[API] No user ID found for $username');
      }
      return null;
    } on DioException catch (e) {
      if (e.error.toString().contains('Redirect loop detected')) {
        if (kDebugMode) {
          print('[API] Redirect loop detected, session may be expired for $username');
        }
        // Session is likely expired, we need to re-login
        throw Exception('Session expired, please re-login');
      }
      if (kDebugMode) {
        print('[API] Error getting user ID for $username: $e');
      }
      throw Exception('Failed to get user ID: $e');
    } catch (e) {
      if (kDebugMode) {
        print('[API] Error getting user ID for $username: $e');
      }
      throw Exception('Failed to get user ID: $e');
    }
  }

  // Follow a user
  Future<bool> followUser(String userId) async {
    try {
      final response = await _dio.post(
        '/api/v1/friendships/create/$userId/',
        data: {'user_id': userId},
      );
      
      return response.statusCode == 200 && response.data['status'] == 'ok';
    } catch (e) {
      throw Exception('Failed to follow user: $e');
    }
  }

  // Unfollow a user
  Future<bool> unfollowUser(String userId) async {
    try {
      final response = await _dio.post(
        '/api/v1/friendships/destroy/$userId/',
        data: {'user_id': userId},
      );
      
      return response.statusCode == 200 && response.data['status'] == 'ok';
    } catch (e) {
      throw Exception('Failed to unfollow user: $e');
    }
  }

  // Helper method to extract CSRF token from HTML
  String? _extractCsrfToken(String html) {
    // Try multiple patterns to find CSRF token
    final patterns = [
      '"csrf_token":"([^"]+)"',
      'csrf_token["\']?\\s*:\\s*["\']([^"\']+)["\']',
      'name=["\']csrfmiddlewaretoken["\']\\s+value=["\']([^"\']+)["\']',
      '<input[^>]*name=["\']csrfmiddlewaretoken["\']\\s+value=["\']([^"\']+)["\']',
      'window\\._sharedData\\s*=\\s*\\{[^}]*"csrf_token":"([^"]+)"',
      '"csrfToken":"([^"]+)"',
      'csrf["\']?\\s*:\\s*["\']([^"\']+)["\']',
    ];
    
    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(html);
      if (match != null && match.group(1) != null && match.group(1)!.isNotEmpty) {
        return match.group(1);
      }
    }
    
    // If no pattern matches, log a portion of the HTML for debugging
    if (kDebugMode) {
      print('CSRF extraction failed. HTML sample:');
      print(html.length > 1000 ? html.substring(0, 1000) + '...' : html);
    }
    
    return null;
  }

  // Helper method to extract rollout hash from HTML
  String? _extractRolloutHash(String html) {
    final patterns = [
      '"rollout_hash":"([^"]+)"',
      'rollout_hash["\']?\\s*:\\s*["\']([^"\']+)["\']',
      '"rolloutHash":"([^"]+)"',
      'rollout["\']?\\s*:\\s*["\']([^"\']+)["\']',
    ];
    
    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(html);
      if (match != null && match.group(1) != null && match.group(1)!.isNotEmpty) {
        return match.group(1);
      }
    }
    
    return null;
  }

  // Helper method to extract cookies from response headers
  Map<String, String> _extractCookies(Headers headers) {
    final cookies = <String, String>{};
    final cookieHeaders = headers['set-cookie'];
    
    if (cookieHeaders != null) {
      for (final cookie in cookieHeaders) {
        final parts = cookie.split(';');
        if (parts.isNotEmpty) {
          final keyValue = parts[0].split('=');
          if (keyValue.length == 2) {
            cookies[keyValue[0].trim()] = keyValue[1].trim();
          }
        }
      }
    }
    
    return cookies;
  }

  // Helper method to extract profile data from HTML
  Map<String, dynamic>? _extractProfileData(String html) {
    try {
      final regex = RegExp(r'window\._sharedData\s*=\s*({.+?});');
      final match = regex.firstMatch(html);
      
      if (match != null) {
        final jsonStr = match.group(1);
        if (jsonStr != null) {
          final data = json.decode(jsonStr);
          final user = data['entry_data']['ProfilePage'][0]['graphql']['user'];
          
          return {
            'username': user['username'],
            'displayName': user['full_name'],
            'profilePictureUrl': user['profile_pic_url_hd'] ?? user['profile_pic_url'],
            'bio': user['biography'],
            'followersCount': user['edge_followed_by']['count'],
            'followingCount': user['edge_follow']['count'],
            'postsCount': user['edge_owner_to_timeline_media']['count'],
            'isVerified': user['is_verified'],
            'isPrivate': user['is_private'],
            'lastSync': DateTime.now().toIso8601String(),
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          };
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }


  // Set session for authenticated requests
  void setSession(String sessionId, String csrfToken) {
    _dio.options.headers['Cookie'] = 'sessionid=$sessionId';
    _dio.options.headers['X-CSRFToken'] = csrfToken;
  }

  // Verify if the current session is still valid
  Future<bool> isSessionValid() async {
    try {
      if (kDebugMode) {
        print('[API] Checking session validity...');
      }
      
      // Check if we have a recent session check
      if (_lastSessionCheck != null && 
          DateTime.now().difference(_lastSessionCheck!).inMinutes < 5) {
        if (kDebugMode) {
          print('[API] Session check was recent, assuming valid');
        }
        return true;
      }

      // Try to access a protected endpoint to verify session
      final response = await _dio.get(
        '/api/v1/accounts/current_user/',
        options: Options(
          headers: {
            'X-IG-App-ID': '936619743392459',
          },
        ),
      );

      _lastSessionCheck = DateTime.now();

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data is Map && data['user'] != null) {
          if (kDebugMode) {
            print('[API] Session is valid');
          }
          return true;
        }
      }

      if (kDebugMode) {
        print('[API] Session is invalid. Status: ${response.statusCode}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('[API] Session validation error: $e');
      }
      _lastSessionCheck = DateTime.now();
      return false;
    }
  }

  // Refresh session by re-logging in
  Future<bool> refreshSession(String username, String password) async {
    try {
      if (kDebugMode) {
        print('[API] Refreshing session for $username...');
      }
      
      // Clear current session
      _dio.options.headers.remove('Cookie');
      _dio.options.headers.remove('X-CSRFToken');
      _csrfToken = null;
      _lastSessionCheck = null;

      // Re-login
      final account = await login(username, password);
      if (account != null) {
        if (kDebugMode) {
          print('[API] Session refreshed successfully');
        }
        return true;
      }

      if (kDebugMode) {
        print('[API] Failed to refresh session');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('[API] Session refresh error: $e');
      }
      return false;
    }
  }

  // Ensure valid session before making API calls
  Future<bool> ensureValidSession(String username, String password) async {
    // Check if session is valid
    final isValid = await isSessionValid();
    if (isValid) {
      return true;
    }

    // Session is invalid, try to refresh
    if (kDebugMode) {
      print('[API] Session invalid, attempting to refresh...');
    }
    return await refreshSession(username, password);
  }

  // Clear session
  void clearSession() {
    _dio.options.headers.remove('Cookie');
    _dio.options.headers.remove('X-CSRFToken');
  }

  // Handle 2FA challenge
  Future<InstagramAccount?> _handleTwoFactorChallenge(
    String username, 
    String password, 
    String csrfToken, 
    String twoFactorCode, 
    Map<String, dynamic> twoFactorInfo
  ) async {
    try {
      // Extract 2FA identifier from the response
      final twoFactorIdentifier = twoFactorInfo['two_factor_info']?['two_factor_identifier'] ?? 
                                 twoFactorInfo['two_factor_identifier'];
      
      if (twoFactorIdentifier == null) {
        throw Exception('Two-factor identifier not found in response');
      }

      // Prepare 2FA data
      final twoFactorData = {
        'username': username,
        'verification_code': twoFactorCode,
        'two_factor_identifier': twoFactorIdentifier,
        'trust_this_device': '1',
        'queryParams': '{}',
      };

      // Set up headers for 2FA
      final twoFactorHeaders = {
        'X-CSRFToken': csrfToken,
        'X-Requested-With': 'XMLHttpRequest',
        'X-Instagram-AJAX': '1',
        'X-ASBD-ID': '129477',
        'X-IG-App-ID': '936619743392459',
        'X-IG-WWW-Claim': '0',
        'Referer': 'https://www.instagram.com/accounts/login/',
        'Origin': 'https://www.instagram.com',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-origin',
        'Sec-Ch-Ua': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
        'Sec-Ch-Ua-Mobile': '?0',
        'Sec-Ch-Ua-Platform': '"Windows"',
      };

      if (kDebugMode) {
        print('[API] Submitting 2FA code: $twoFactorCode');
        print('[API] 2FA data: $twoFactorData');
        print('[API] 2FA identifier: $twoFactorIdentifier');
      }

      // Submit 2FA code
      final twoFactorResponse = await _dio.post(
        '/api/v1/accounts/two_factor_login/',
        data: twoFactorData,
        options: Options(
          headers: twoFactorHeaders,
          contentType: 'application/x-www-form-urlencoded',
          validateStatus: (status) => status! < 500,
        ),
      );

      if (kDebugMode) {
        print('[API] 2FA response status: ${twoFactorResponse.statusCode}');
        print('[API] 2FA response data: ${twoFactorResponse.data}');
      }

      if (twoFactorResponse.statusCode == 200) {
        final responseData = twoFactorResponse.data;
        
        if (responseData['authenticated'] == true) {
          // Extract session cookies
          final cookies = _extractCookies(twoFactorResponse.headers);
          final sessionId = cookies['sessionid'];
          
          if (sessionId != null) {
            // Create account object
            final account = InstagramAccount(
              username: username,
              password: password, // In production, encrypt this
              sessionId: sessionId,
              csrfToken: csrfToken,
              isActive: true,
              lastLogin: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            return account;
          } else {
            throw Exception('Failed to extract session ID from 2FA response');
          }
        } else {
          final errorMessage = responseData['message'] ?? responseData['error_type'] ?? '2FA verification failed';
          if (kDebugMode) {
            print('[API] 2FA verification failed. Response: $responseData');
            print('[API] Error message: $errorMessage');
          }
          throw Exception('2FA verification failed: $errorMessage');
        }
      } else {
        final responseData = twoFactorResponse.data;
        final errorMessage = responseData['message'] ?? responseData['error_type'] ?? '2FA request failed';
        if (kDebugMode) {
          print('[API] 2FA request failed with status ${twoFactorResponse.statusCode}');
          print('[API] Response data: $responseData');
          print('[API] Error message: $errorMessage');
        }
        throw Exception('2FA request failed: $errorMessage');
      }
    } catch (e) {
      if (e is TwoFactorRequiredException) {
        rethrow;
      }
      throw Exception('2FA challenge error: $e');
    }
  }

  Future<void> request2FASMS(String username, String twoFactorIdentifier) async {
    // Check if we've requested SMS recently (within last 2 minutes)
    if (_lastSMSRequest != null && 
        DateTime.now().difference(_lastSMSRequest!).inMinutes < 2) {
      if (kDebugMode) {
        print('[API] SMS already requested recently, skipping to avoid rate limiting');
      }
      return;
    }

    try {
      _lastSMSRequest = DateTime.now();
      final csrfToken = await getCsrfToken();
      final response = await _dio.post(
        '/api/v1/accounts/send_two_factor_login_sms/',
        data: {
          'username': username,
          'two_factor_identifier': twoFactorIdentifier,
          'device_id': 'android-${DateTime.now().millisecondsSinceEpoch}', // Generate a generic device ID
        },
        options: Options(
          validateStatus: (status) => status! < 500,
          contentType: 'application/x-www-form-urlencoded',
          headers: {
            'X-CSRFToken': csrfToken,
            'X-Requested-With': 'XMLHttpRequest',
            'X-Instagram-AJAX': _rolloutHash ?? '1',
            'X-ASBD-ID': '129477',
            'X-IG-App-ID': '936619743392459',
            'X-IG-WWW-Claim': '0',
            'Referer': 'https://www.instagram.com/accounts/login/',
            'Origin': 'https://www.instagram.com',
            'Accept': '*/*',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
            'Sec-Fetch-Dest': 'empty',
            'Sec-Fetch-Mode': 'cors',
            'Sec-Fetch-Site': 'same-origin',
            'Sec-Ch-Ua': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
            'Sec-Ch-Ua-Mobile': '?0',
            'Sec-Ch-Ua-Platform': '"Windows"',
          },
        ),
      );

      if (response.statusCode != 200 || response.data?['status'] != 'ok') {
        final errorMessage = response.data?['message'] ?? 'Failed to request SMS';
        throw Exception('Failed to request 2FA SMS: $errorMessage');
      }
      if (kDebugMode) {
        print('Successfully requested 2FA SMS. Response: ${response.data}');
      }
    } catch (e) {
      throw Exception('Error requesting 2FA SMS: $e');
    }
  }

  Future<void> request2FAEmail(String twoFactorIdentifier) async {
    // TODO: Implement email request if needed
    throw UnimplementedError('Email 2FA request is not yet implemented.');
  }

  Future<String> getCsrfToken() async {
    if (_csrfToken != null && _csrfToken!.isNotEmpty) {
      return _csrfToken!;
    }

    try {
      final response = await _dio.get('/accounts/login/');
      if (kDebugMode) {
        print('Login page response status: ${response.statusCode}');
      }
      
      String? csrfToken = _extractCsrfToken(response.data);
      
      if (csrfToken == null) {
        final cookies = _extractCookies(response.headers);
        final csrfFromCookie = cookies['csrftoken'];
        
        if (csrfFromCookie != null && csrfFromCookie.isNotEmpty) {
          csrfToken = csrfFromCookie;
        } else {
          throw Exception('Failed to extract CSRF token from Instagram login page.');
        }
      }
      
      _csrfToken = csrfToken;
      _rolloutHash = _extractRolloutHash(response.data);
      return _csrfToken!;
    } catch (e) {
      throw Exception('Failed to fetch CSRF token: $e');
    }
  }
}

// Custom cookie interceptor that can handle malformed cookies
class _CustomCookieInterceptor extends Interceptor {
  final Map<String, String> _cookies = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Add cookies to request headers
    if (_cookies.isNotEmpty) {
      final cookieString = _cookies.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
      options.headers['Cookie'] = cookieString;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Parse Set-Cookie headers and store them
    final setCookieHeaders = response.headers['set-cookie'];
    if (setCookieHeaders != null) {
      for (final cookieHeader in setCookieHeaders) {
        try {
          _parseCookie(cookieHeader);
        } catch (e) {
          // Skip malformed cookies instead of crashing
          if (kDebugMode) {
            print('[CookieInterceptor] Skipping malformed cookie: $cookieHeader');
          }
        }
      }
    }
    handler.next(response);
  }

  void _parseCookie(String cookieHeader) {
    // Split by semicolon and take the first part (name=value)
    final parts = cookieHeader.split(';');
    if (parts.isNotEmpty) {
      final nameValue = parts[0].trim();
      final equalIndex = nameValue.indexOf('=');
      if (equalIndex > 0) {
        final name = nameValue.substring(0, equalIndex).trim();
        final value = nameValue.substring(equalIndex + 1).trim();
        
        // Clean up the value by removing problematic characters
        final cleanValue = _cleanCookieValue(value);
        if (cleanValue.isNotEmpty) {
          _cookies[name] = cleanValue;
        }
      }
    }
  }

  String _cleanCookieValue(String value) {
    // Remove or replace problematic characters
    return value
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '') // Remove non-printable characters
        .replaceAll('\\054', ',') // Replace \054 with comma
        .replaceAll('\\', '') // Remove backslashes
        .trim();
  }
}

