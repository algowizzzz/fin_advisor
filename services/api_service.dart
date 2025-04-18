import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class APIService {
  String? _baseUrl;

  Future<void> discoverBackendPort() async {
    // Try ports 5001-5010
    for (int port = 5001; port <= 5010; port++) {
      try {
        final response = await http
            .get(Uri.parse('http://localhost:$port/'))
            .timeout(const Duration(seconds: 1));
        
        if (response.statusCode == 200) {
          _baseUrl = 'http://localhost:$port';
          print('Discovered backend at port $port');
          break;
        }
      } catch (e) {
        // Continue trying other ports
      }
    }
  }

  Future<dynamic> _handleRequest(Future<http.Response> Function() requestFunction) async {
    try {
      final response = await requestFunction();
      
      // Debug response
      print('API response received: ${response.body.substring(0, min(100, response.body.length))}...');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        // Clear token on authentication failure
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        throw Exception('Authentication failed: ${response.statusCode}, ${response.body}');
      } else {
        throw Exception('Failed to load data: ${response.statusCode}, ${response.body}');
      }
    } on SocketException {
      print('API error: No Internet connection');
      throw Exception('No Internet connection');
    } on TimeoutException {
      print('API error: Connection timeout');
      throw Exception('Connection timeout');
    } on FormatException {
      print('API error: Invalid response format');
      throw Exception('Invalid response format');
    } catch (e) {
      print('API error: $e');
      throw Exception('Error: $e');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await post(
        '/api/users/login',
        {
          'email': email,
          'password': password,
        },
      );
      
      if (response['success'] == true && response['token'] != null) {
        // Store the token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', response['token']);
        await prefs.setString('userId', response['user']['_id']);
        await prefs.setString('userEmail', response['user']['email']);
        await prefs.setString('userName', response['user']['name'] ?? 'User');
        
        // Debug successful login
        print('Login successful! User ID: ${response['user']['_id']}');
        
        return response;
      } else {
        throw Exception('Login failed: ${response['message']}');
      }
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }
} 