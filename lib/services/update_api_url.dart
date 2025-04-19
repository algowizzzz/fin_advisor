import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class ApiUrlUpdater {
  static const String _baseUrlKey = 'api_base_url';
  static const String _remoteServerKey = 'use_remote_server';
  static const String _remoteUrl = 'http://44.207.118.69:5001/api';
  static const String _localUrl = 'http://localhost:5001/api';
  
  /// Sets the API URL to the remote server
  static Future<bool> setRemoteServer() async {
    try {
      // Update in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_baseUrlKey, _remoteUrl);
      await prefs.setBool(_remoteServerKey, true);
      
      // Update in ApiService
      final apiService = ApiService();
      await apiService.setBaseUrl(_remoteUrl);
      
      print('API URL updated to remote server: $_remoteUrl');
      return true;
    } catch (e) {
      print('Error updating API URL: $e');
      return false;
    }
  }
  
  /// Sets the API URL back to localhost
  static Future<bool> setLocalServer() async {
    try {
      // Update in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_baseUrlKey, _localUrl);
      await prefs.setBool(_remoteServerKey, false);
      
      // Update in ApiService
      final apiService = ApiService();
      await apiService.setBaseUrl(_localUrl);
      
      print('API URL reset to local server: $_localUrl');
      return true;
    } catch (e) {
      print('Error updating API URL: $e');
      return false;
    }
  }
  
  /// Gets the current API URL
  static Future<String> getCurrentUrl() async {
    try {
      final apiService = ApiService();
      final url = await apiService.baseUrl;
      return url;
    } catch (e) {
      print('Error getting current API URL: $e');
      return '';
    }
  }
  
  /// Checks if the remote server is currently enabled
  static Future<bool> isRemoteServerEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_remoteServerKey) ?? false;
    } catch (e) {
      print('Error checking if remote server is enabled: $e');
      return false;
    }
  }
  
  /// Returns the remote server URL constant
  static String get remoteUrl => _remoteUrl;
  
  /// Returns the local server URL constant
  static String get localUrl => _localUrl;
} 