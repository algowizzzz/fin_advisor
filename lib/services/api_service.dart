import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Base URL for API
  static const String _baseUrlKey = 'api_base_url';
  static const String _defaultBaseUrl = 'http://localhost:5001/api';
  String? _cachedBaseUrl;
  
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  
  factory ApiService() {
    return _instance;
  }
  
  ApiService._internal();
  
  // Get the base URL, either from cache, SharedPreferences, or default
  Future<String> get baseUrl async {
    if (_cachedBaseUrl != null) {
      return _cachedBaseUrl!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    _cachedBaseUrl = prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
    return _cachedBaseUrl!;
  }
  
  // Set a new base URL and save it to SharedPreferences
  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
    _cachedBaseUrl = url;
  }
  
  // Try connecting to various ports to discover the backend
  Future<bool> discoverBackendPort() async {
    bool discovered = false;
    for (int port = 5001; port <= 5010; port++) {
      final testUrl = 'http://localhost:$port/';
      try {
        final response = await http.get(Uri.parse(testUrl))
            .timeout(const Duration(seconds: 2));
        
        if (response.statusCode == 200) {
          await setBaseUrl('http://localhost:$port/api');
          print('Discovered backend at port $port');
          discovered = true;
          break;
        }
      } catch (e) {
        // Continue trying next port
      }
    }
    return discovered;
  }
  
  // Headers
  Map<String, String> _headers(String? token) {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
  
  // GET request
  Future<dynamic> get(String endpoint, {String? token}) async {
    try {
      final response = await http.get(
        Uri.parse('${await baseUrl}/$endpoint'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 10));
      
      return _handleResponse(response);
    } catch (e) {
      print('GET request error: $e');
      rethrow;
    }
  }
  
  // POST request
  Future<dynamic> post(String endpoint, Map<String, dynamic> data, {String? token}) async {
    try {
      final response = await http.post(
        Uri.parse('${await baseUrl}/$endpoint'),
        headers: _headers(token),
        body: json.encode(data),
      ).timeout(const Duration(seconds: 10));
      
      return _handleResponse(response);
    } catch (e) {
      print('POST request error: $e');
      rethrow;
    }
  }
  
  // PUT request
  Future<dynamic> put(String endpoint, Map<String, dynamic> data, {String? token}) async {
    try {
      final response = await http.put(
        Uri.parse('${await baseUrl}/$endpoint'),
        headers: _headers(token),
        body: json.encode(data),
      ).timeout(const Duration(seconds: 10));
      
      return _handleResponse(response);
    } catch (e) {
      print('PUT request error: $e');
      rethrow;
    }
  }
  
  // DELETE request
  Future<dynamic> delete(String endpoint, {String? token}) async {
    try {
      final response = await http.delete(
        Uri.parse('${await baseUrl}/$endpoint'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 10));
      
      return _handleResponse(response);
    } catch (e) {
      print('DELETE request error: $e');
      rethrow;
    }
  }
  
  // Handle API response
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      // Clear token on authentication failure
      _clearAuthData();
      throw Exception('Authentication failed: ${response.statusCode}, ${response.body}');
    } else {
      throw Exception('Failed to load data: ${response.statusCode}, ${response.body}');
    }
  }
  
  // Clear authentication data
  Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('userEmail');
    await prefs.remove('userName');
  }
  
  // Check if the backend is available and if we're authenticated
  Future<Map<String, bool>> checkConnection() async {
    Map<String, bool> status = {
      'backendAvailable': false,
      'databaseConnected': false,
      'authenticated': false,
    };
    
    try {
      // Check if backend is running
      try {
        final healthCheckUrl = '${await baseUrl}/health-check';
        final healthCheck = await http.get(
          Uri.parse(healthCheckUrl),
        ).timeout(const Duration(seconds: 3));
        
        if (healthCheck.statusCode == 200) {
          status['backendAvailable'] = true;
          try {
            final healthData = json.decode(healthCheck.body);
            status['databaseConnected'] = healthData['database'] == true;
          } catch (e) {
            // JSON parsing failed
          }
        }
      } catch (e) {
        // Health check endpoint failed, try root endpoint
        try {
          final rootUrl = (await baseUrl).replaceAll('/api', '');
          final rootCheck = await http.get(
            Uri.parse(rootUrl),
          ).timeout(const Duration(seconds: 2));
          
          if (rootCheck.statusCode == 200) {
            status['backendAvailable'] = true;
          }
        } catch (e) {
          // Root endpoint check failed
        }
      }
      
      // Check if we have a token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token != null && token.isNotEmpty) {
        try {
          // Verify token with backend
          final verifyUrl = '${await baseUrl}/users/verify-token';
          final authCheck = await http.get(
            Uri.parse(verifyUrl),
            headers: _headers(token),
          ).timeout(const Duration(seconds: 3));
          
          if (authCheck.statusCode == 200) {
            status['authenticated'] = true;
          } else if (authCheck.statusCode == 401) {
            // Token is invalid, clear it
            await _clearAuthData();
          }
        } catch (e) {
          // Token verification failed, but don't clear token
          // as it might be a server issue
          print('Token verification failed: $e');
        }
      }
    } catch (e) {
      print('Connection check failed: $e');
    }
    
    print('Connection status: Backend=${status['backendAvailable']}, DB=${status['databaseConnected']}, Auth=${status['authenticated']}');
    return status;
  }
  
  // Login method
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Clear any existing authentication data first
      await _clearAuthData();
      
      final response = await post(
        'users/login',
        {
          'email': email,
          'password': password,
        },
      );
      
      if (response != null && response['token'] != null) {
        // Store the token and user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', response['token']);
        await prefs.setString('userId', response['user']['id']);
        await prefs.setString('userEmail', response['user']['email']);
        await prefs.setString('userName', response['user']['fullName'] ?? 'User');
        
        print('Login successful! User ID: ${response['user']['id']}');
        return response;
      } else {
        throw Exception('Login failed: Invalid response format');
      }
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }
  
  // Get user ID from token or shared preferences
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }
} 