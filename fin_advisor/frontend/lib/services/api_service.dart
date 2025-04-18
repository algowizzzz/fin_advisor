import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Base URL for API
  final String baseUrl = 'http://localhost:3000/api';
  
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  
  factory ApiService() {
    return _instance;
  }
  
  ApiService._internal();
  
  // Headers
  Map<String, String> _headers(String? token) {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
  
  // GET request
  Future<dynamic> get(String endpoint, {String? token}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$endpoint'),
      headers: _headers(token),
    );
    
    return _handleResponse(response);
  }
  
  // POST request
  Future<dynamic> post(String endpoint, Map<String, dynamic> data, {String? token}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: _headers(token),
      body: json.encode(data),
    );
    
    return _handleResponse(response);
  }
  
  // PUT request
  Future<dynamic> put(String endpoint, Map<String, dynamic> data, {String? token}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/$endpoint'),
      headers: _headers(token),
      body: json.encode(data),
    );
    
    return _handleResponse(response);
  }
  
  // DELETE request
  Future<dynamic> delete(String endpoint, {String? token}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/$endpoint'),
      headers: _headers(token),
    );
    
    return _handleResponse(response);
  }
  
  // Handle API response
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load data: ${response.statusCode}, ${response.body}');
    }
  }
} 