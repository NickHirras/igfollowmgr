import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import '../models/instagram_account.dart';
import '../models/instagram_user.dart';
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
  final CookieJar _cookieJar = CookieJar();
  static const String _baseUrl = 'https://www.instagram.com';
  String? _csrfToken;
  String? _rolloutHash;

  // Initialize the service
  void initialize() {
    _dio.options.baseUrl = _baseUrl;
    _dio.interceptors.add(CookieManager(_cookieJar));
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
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
        'Accept-Encoding': 'gzip, deflate, br',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
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
              await request2FASMS(username, twoFactorIdentifier);
            }
          } catch (e) {
            if (kDebugMode) {
              print('Failed to automatically request 2FA SMS from 400 error: $e');
            }
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
  Future<FollowersResponse> getFollowers(String username, {String? maxId}) async {
    try {
      final url = '/api/v1/friendships/$username/followers/';
      final queryParams = <String, dynamic>{
        'count': '200',
        'search_surface': 'follow_list_page',
      };
      
      if (maxId != null) {
        queryParams['max_id'] = maxId;
      }

      final response = await _dio.get(url, queryParameters: queryParams);
      
      if (response.statusCode == 200) {
        return FollowersResponse.fromJson(response.data);
      }
      
      return FollowersResponse(users: [], nextMaxId: null);
    } catch (e) {
      throw Exception('Failed to get followers: $e');
    }
  }

  // Get following list
  Future<FollowersResponse> getFollowing(String username, {String? maxId}) async {
    try {
      final url = '/api/v1/friendships/$username/following/';
      final queryParams = <String, dynamic>{
        'count': '200',
      };
      
      if (maxId != null) {
        queryParams['max_id'] = maxId;
      }

      final response = await _dio.get(url, queryParameters: queryParams);
      
      if (response.statusCode == 200) {
        return FollowersResponse.fromJson(response.data);
      }
      
      return FollowersResponse(users: [], nextMaxId: null);
    } catch (e) {
      throw Exception('Failed to get following: $e');
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

  // Helper method to parse Instagram user data
  InstagramUser? _parseInstagramUser(Map<String, dynamic> userData) {
    try {
      return InstagramUser(
        username: userData['username'] ?? '',
        fullName: userData['full_name'],
        profilePictureUrl: userData['profile_pic_url'],
        isVerified: userData['is_verified'] ?? false,
        isPrivate: userData['is_private'] ?? false,
        isBusiness: userData['is_business'] ?? false,
        externalUrl: userData['external_url'],
        followersCount: userData['follower_count'],
        followingCount: userData['following_count'],
        postsCount: userData['media_count'],
        biography: userData['biography'],
        followedAt: userData['followed_at'] != null 
            ? DateTime.tryParse(userData['followed_at']) 
            : null,
        followingAt: userData['following_at'] != null 
            ? DateTime.tryParse(userData['following_at']) 
            : null,
        lastSeen: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  // Set session for authenticated requests
  void setSession(String sessionId, String csrfToken) {
    _dio.options.headers['Cookie'] = 'sessionid=$sessionId';
    _dio.options.headers['X-CSRFToken'] = csrfToken;
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
        'Accept-Encoding': 'gzip, deflate, br',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-origin',
        'Sec-Ch-Ua': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
        'Sec-Ch-Ua-Mobile': '?0',
        'Sec-Ch-Ua-Platform': '"Windows"',
      };

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
          throw Exception('2FA verification failed: $errorMessage');
        }
      } else {
        final responseData = twoFactorResponse.data;
        final errorMessage = responseData['message'] ?? responseData['error_type'] ?? '2FA request failed';
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
    try {
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
            'Accept-Encoding': 'gzip, deflate, br',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
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

