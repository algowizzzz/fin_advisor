import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isConnected = false;
  bool _isDatabaseConnected = false;
  bool _isAuthenticated = false;
  String _apiUrl = '';
  String _userName = 'User';
  String _userEmail = '';
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _checkConnection();
  }

  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('userName');
      final userEmail = prefs.getString('userEmail');
      
      if (mounted) {
        setState(() {
          _userName = userName ?? 'User';
          _userEmail = userEmail ?? '';
        });
      }
    } catch (e) {
      print('Error loading user info: $e');
    }
  }

  Future<void> _checkConnection() async {
    try {
      final connectionStatus = await _apiService.checkConnection();
      
      if (mounted) {
        setState(() {
          _isConnected = connectionStatus['backendAvailable'] ?? false;
          _isDatabaseConnected = connectionStatus['databaseConnected'] ?? false;
          _isAuthenticated = connectionStatus['authenticated'] ?? false;
        });
      }
      
      final url = await _apiService.baseUrl;
      if (mounted) {
        setState(() {
          _apiUrl = url;
        });
      }
      
      print('Connection status: Backend=${_isConnected}, DB=${_isDatabaseConnected}, Auth=${_isAuthenticated}');
    } catch (e) {
      print('Error checking connection: $e');
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isDatabaseConnected = false;
          _isAuthenticated = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Dashboard'),
        actions: [
          // Connection status indicator
          IconButton(
            icon: Icon(_isConnected 
                ? _isDatabaseConnected 
                    ? Icons.cloud_done
                    : Icons.cloud_queue
                : Icons.cloud_off),
            color: _isConnected
                ? _isDatabaseConnected 
                    ? Colors.green
                    : Colors.orange
                : Colors.red,
            tooltip: _isConnected 
                ? _isDatabaseConnected 
                    ? 'Connected to database' 
                    : 'Backend connected, database offline'
                : 'Offline mode',
            onPressed: () {
              _showConnectionStatus(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Navigate to notifications page
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // Navigate to profile page
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF0073CF),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Color(0xFF0073CF),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    _userEmail,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: true,
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Interactive Dashboard'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/dashboard');
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Income'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/income');
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Expenses'),
              onTap: () {
                // Close the drawer first
                Navigator.pop(context);
                // Use pushNamed to navigate to the expenses screen
                Navigator.of(context).pushNamed('/expenses');
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance),
              title: const Text('Assets'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to assets page
                Navigator.of(context).pushNamed('/assets');
              },
            ),
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: const Text('Liabilities'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to liabilities page
                Navigator.of(context).pushNamed('/liabilities');
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('Goals'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/goals');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Chat with Advisor'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to chat page
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.pop(context);
                // Clear user data
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('token');
                await prefs.remove('userId');
                await prefs.remove('userEmail');
                await prefs.remove('userName');
                // Navigate to login screen
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(context, '/dashboard');
                },
                borderRadius: BorderRadius.circular(15),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Interactive Dashboard',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Icon(
                            Icons.analytics,
                            color: Colors.white.withOpacity(0.8),
                            size: 30,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'View all your financial data in one place with interactive charts and insights',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Open Dashboard',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 5),
                            Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Financial Summary',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 4,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Monthly Income'),
                      Text(
                        '\$5,000',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Monthly Expenses'),
                      Text(
                        '\$3,500',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Divider(),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Monthly Surplus'),
                      Text(
                        '\$1,500',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Recommended Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildActionCard(
                    context,
                    icon: Icons.trending_up,
                    title: 'Increase Emergency Fund',
                    description: 'Your emergency fund covers only 2 months of expenses. Consider adding to it.',
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    icon: Icons.credit_card,
                    title: 'Pay off High-Interest Debt',
                    description: 'You have a credit card with 20% APR. Prioritize paying this off first.',
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    icon: Icons.savings,
                    title: 'Start Investing',
                    description: 'With your monthly surplus, consider investing for long-term growth.',
                    color: Colors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to add new financial data page
        },
        backgroundColor: const Color(0xFF0073CF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConnectionStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _isConnected 
                ? _isDatabaseConnected 
                    ? Icons.cloud_done
                    : Icons.cloud_queue
                : Icons.cloud_off,
              color: _isConnected
                ? _isDatabaseConnected 
                    ? Colors.green
                    : Colors.orange
                : Colors.red,
            ),
            const SizedBox(width: 10),
            const Text('Connection Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(
                _isConnected ? Icons.check_circle : Icons.error,
                color: _isConnected ? Colors.green : Colors.red,
              ),
              title: const Text('Backend API'),
              subtitle: Text(_isConnected 
                ? 'Connected to $_apiUrl' 
                : 'Disconnected'),
            ),
            ListTile(
              leading: Icon(
                _isDatabaseConnected ? Icons.check_circle : Icons.error,
                color: _isDatabaseConnected ? Colors.green : Colors.red,
              ),
              title: const Text('Database'),
              subtitle: Text(_isDatabaseConnected 
                ? 'Connected' 
                : 'Disconnected'),
            ),
            ListTile(
              leading: Icon(
                _isAuthenticated ? Icons.check_circle : Icons.error,
                color: _isAuthenticated ? Colors.green : Colors.red,
              ),
              title: const Text('Authentication'),
              subtitle: Text(_isAuthenticated 
                ? 'Authenticated as $_userName' 
                : 'Not authenticated'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _checkConnection();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Connection status refreshed'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Refresh'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
} 