import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../app_config.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get instance {
    assert(_prefs != null, 'StorageService not initialized');
    return _prefs!;
  }

  // Token management
  static Future<void> saveToken(String token) async {
    await instance.setString(AppConfig.tokenKey, token);
  }

  static String? getToken() {
    return instance.getString(AppConfig.tokenKey);
  }

  static Future<void> removeToken() async {
    await instance.remove(AppConfig.tokenKey);
  }

  static bool hasToken() {
    return instance.containsKey(AppConfig.tokenKey);
  }

  // User data management
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    await instance.setString(AppConfig.userDataKey, jsonEncode(userData));
  }

  static Map<String, dynamic>? getUserData() {
    final userDataString = instance.getString(AppConfig.userDataKey);
    if (userDataString != null) {
      try {
        return jsonDecode(userDataString);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<void> removeUserData() async {
    await instance.remove(AppConfig.userDataKey);
  }

  // Settings management
  static Future<void> saveSetting(String key, dynamic value) async {
    if (value is String) {
      await instance.setString(key, value);
    } else if (value is int) {
      await instance.setInt(key, value);
    } else if (value is bool) {
      await instance.setBool(key, value);
    } else if (value is double) {
      await instance.setDouble(key, value);
    } else {
      await instance.setString(key, jsonEncode(value));
    }
  }

  static T? getSetting<T>(String key) {
    if (T == String) {
      return instance.getString(key) as T?;
    } else if (T == int) {
      return instance.getInt(key) as T?;
    } else if (T == bool) {
      return instance.getBool(key) as T?;
    } else if (T == double) {
      return instance.getDouble(key) as T?;
    } else {
      final value = instance.getString(key);
      if (value != null) {
        try {
          return jsonDecode(value) as T;
        } catch (e) {
          return null;
        }
      }
      return null;
    }
  }

  // Clear all data
  static Future<void> clearAll() async {
    await instance.clear();
  }
}