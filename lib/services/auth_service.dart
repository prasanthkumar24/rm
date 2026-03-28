import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';

class SessionValidationResult {
  final bool isValid;
  final bool isServerAvailable;
  SessionValidationResult({required this.isValid, required this.isServerAvailable});
}

class AuthService {
  static const String _kServerUrlKey = 'server_url';
  static const String _kAccessTokenKey = 'access_token';
  static const String _kUserIdKey = 'user_id';
  static const String _kUserNameKey = 'user_name';
  static const String _kDeviceIdKey = 'device_id';
  static const String _kMobileAuthenticatedKey = 'mobile_authenticated';
  static const String _kVideoUsernameKey = 'video_username';
  static const String _kVideoPasswordKey = 'video_password';

  static const String _kBaseOtpUrl = 'https://api.rmoffice.online';

  String _mapError(dynamic e) {
    final errorStr = e.toString().toLowerCase();
    
    // Check for specific API error messages first
    if (errorStr.contains('mobile number not registered')) {
      return 'MOBILE NUMBER NOT REGISTERED. ACCESS DENIED.';
    } else if (errorStr.contains('too many otp requests')) {
      return 'TOO MANY OTP REQUESTS. PLEASE TRY LATER.';
    } else if (errorStr.contains('invalid or expired otp')) {
      return 'INVALID OR EXPIRED OTP CODE.';
    }

    if (errorStr.contains('socketexception') || errorStr.contains('httpexception')) {
      return 'VIDEO SERVER NOT AVAILABLE. PLEASE CHECK INTERNET.';
    } else if (errorStr.contains('timeout')) {
      return 'CONNECTION TIMEOUT. PLEASE TRY AGAIN.';
    } else if (errorStr.contains('user not found') || errorStr.contains('number not found')) {
      return 'MOBILE NUMBER NOT REGISTERED.';
    } else if (errorStr.contains('invalid otp')) {
      return 'INVALID OTP. PLEASE CHECK AND TRY AGAIN.';
    } else if (errorStr.contains('otp expired')) {
      return 'OTP EXPIRED. PLEASE RESEND.';
    } else if (errorStr.contains('failed to send otp')) {
      return 'OTP SERVICE FAILED. PLEASE TRY LATER.';
    }
    return 'AN UNEXPECTED ERROR OCCURRED. PLEASE TRY AGAIN.';
  }

  Future<Map<String, dynamic>> sendOtp(String mobileNumber) async {
    final url = Uri.parse('$_kBaseOtpUrl/api/send_otp');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'mobile_number': mobileNumber},
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return data;
      } else {
        // Return the actual message from the API if available
        throw Exception(data['message'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      // Re-throw with mapped error message
      throw Exception(_mapError(e));
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String mobileNumber, String otpCode) async {
    final url = Uri.parse('$_kBaseOtpUrl/api/verify_otp');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'mobile_number': mobileNumber,
          'otp_code': otpCode,
        },
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to verify OTP');
      }
    } catch (e) {
      throw Exception(_mapError(e));
    }
  }

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_kDeviceIdKey);
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString(_kDeviceIdKey, deviceId);
    }
    return deviceId;
  }

  Future<User?> login(String serverUrl, String username, String password) async {
    // Normalize URL
    if (serverUrl.endsWith('/')) {
      serverUrl = serverUrl.substring(0, serverUrl.length - 1);
    }

    final deviceId = await _getDeviceId();
    final url = Uri.parse('$serverUrl/Users/AuthenticateByName');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Emby-Authorization': 'MediaBrowser Client="RM LIVE", Device="FlutterApp", DeviceId="$deviceId", Version="1.0.0"',
        },
        body: json.encode({
          'Username': username,
          'Pw': password,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final user = data['User'];
        final accessToken = data['AccessToken'];
        
        final userModel = User.fromJson(user, serverUrl, accessToken);
        await _saveSession(userModel);
        return userModel;
      } else if (response.statusCode == 401) {
        throw Exception('INVALID CREDENTIALS. PLEASE CONTACT ADMIN.');
      } else {
        throw Exception('VIDEO SERVER ERROR: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Login error: $e');
      throw Exception(_mapError(e));
    }
  }

  Future<void> _saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kServerUrlKey, user.serverUrl);
    await prefs.setString(_kAccessTokenKey, user.accessToken);
    await prefs.setString(_kUserIdKey, user.id);
    await prefs.setString(_kUserNameKey, user.name);
  }

  Future<void> saveVideoCredentials(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVideoUsernameKey, username);
    await prefs.setString(_kVideoPasswordKey, password);
  }

  Future<Map<String, String?>> getVideoCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'username': prefs.getString(_kVideoUsernameKey),
      'password': prefs.getString(_kVideoPasswordKey),
    };
  }

  Future<User?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString(_kServerUrlKey);
    final accessToken = prefs.getString(_kAccessTokenKey);
    final userId = prefs.getString(_kUserIdKey);
    final userName = prefs.getString(_kUserNameKey);

    if (serverUrl != null && accessToken != null && userId != null && userName != null) {
      return User(
        id: userId,
        name: userName,
        accessToken: accessToken,
        serverUrl: serverUrl,
      );
    }
    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<SessionValidationResult> validateSession(User user) async {
    final url = Uri.parse('${user.serverUrl}/Users/Me?api_key=${user.accessToken}');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 401) {
        return SessionValidationResult(isValid: false, isServerAvailable: true);
      }
      return SessionValidationResult(isValid: true, isServerAvailable: true);
    } catch (e) {
      debugPrint('Session validation error (likely unreachable): $e');
      // If server is unreachable, we still consider the session "valid" (cached)
      // but we mark the server as unavailable.
      return SessionValidationResult(isValid: true, isServerAvailable: false);
    }
  }

  Future<void> setMobileAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMobileAuthenticatedKey, true);
  }

  Future<bool> isMobileAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kMobileAuthenticatedKey) ?? false;
  }
}
