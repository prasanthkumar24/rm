import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';

class AuthService {
  static const String _kServerUrlKey = 'server_url';
  static const String _kAccessTokenKey = 'access_token';
  static const String _kUserIdKey = 'user_id';
  static const String _kUserNameKey = 'user_name';
  static const String _kDeviceIdKey = 'device_id';

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
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final user = data['User'];
        final accessToken = data['AccessToken'];
        
        final userModel = User.fromJson(user, serverUrl, accessToken);
        await _saveSession(userModel);
        return userModel;
      } else {
        throw Exception('Login failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  Future<void> _saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kServerUrlKey, user.serverUrl);
    await prefs.setString(_kAccessTokenKey, user.accessToken);
    await prefs.setString(_kUserIdKey, user.id);
    await prefs.setString(_kUserNameKey, user.name);
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
}
