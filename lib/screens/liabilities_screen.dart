import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../models/liability_model.dart';
import '../services/api_service.dart';

class LiabilitiesScreen extends StatefulWidget {
  const LiabilitiesScreen({Key? key}) : super(key: key);

  @override
  State<LiabilitiesScreen> createState() => _LiabilitiesScreenState();
}

class _LiabilitiesScreenState extends State<LiabilitiesScreen> {
  bool _isLoading = true;
  List<Liability> _liabilities = [];
  String? _errorMessage;
  bool _useMockData = false;
  final ApiService _apiService = ApiService();
  final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  String _selectedType = 'All';
  List<String> _liabilityTypes = ['All', 'Credit Card', 'Mortgage', 'Auto Loan', 'Student Loan', 'Personal Loan', 'Medical Debt', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadLiabilities();
  }

  Future<void> _loadLiabilities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get token for authorization
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userId = prefs.getString('userId');
      
      // If no token or userId starts with 'mock', go straight to mock data
      if (token == null || (userId != null && (userId.startsWith('mock') || userId.startsWith('offline')))) {
        await _loadMockLiabilities();
        return;
      }

      try {
        // Load liabilities from API
        final response = await _apiService.get('liabilities', token: token);
        
        print('API response received: ${response.toString().substring(0, min(100, response.toString().length))}...');
        
        // Handle various response formats
        List<dynamic> liabilitiesData;
        if (response is List) {
          // Direct array response
          liabilitiesData = response;
        } else if (response is Map<String, dynamic>) {
          if (response.containsKey('success') && response['success'] == true) {
            // Standard success format
            liabilitiesData = response['data'] ?? [];
          } else if (response.containsKey('data') && response['data'] is List) {
            // Only data field
            liabilitiesData = response['data'];
          } else {
            // Unknown format with data
            throw Exception('Invalid response format: ${response.toString().substring(0, min(100, response.toString().length))}...');
          }
        } else {
          throw Exception('Unknown response type: ${response.runtimeType}');
        }
        
        setState(() {
          _liabilities = liabilitiesData.map((json) => Liability.fromJson(json)).toList();
          
          // Filter liabilities if a specific type is selected
          if (_selectedType != 'All') {
            _liabilities = _liabilities.where((liability) => liability.type == _selectedType).toList();
          }
          
          // Sort by amount descending
          _liabilities.sort((a, b) => b.amount.compareTo(a.amount));
          _isLoading = false;
          _useMockData = false;
        });
      } catch (apiError) {
        print('API error: $apiError');
        // If API fails, load mock data
        await _loadMockLiabilities();
      }
    } catch (e) {
      print('Error loading liabilities: $e');
      // Even if there's an error getting dates or tokens, load mock data
      await _loadMockLiabilities();
    }
  }

  Future<void> _loadMockLiabilities() async {
    try {
      // Get user ID if available for more realistic mock data
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? 'offline-${DateTime.now().millisecondsSinceEpoch}';
      
      setState(() {
        // Mock liabilities with safe IDs that won't conflict with MongoDB ObjectId
        _liabilities = [
          Liability(
            id: 'mock-1',
            userId: userId,
            name: 'Home Mortgage',
            type: 'Mortgage',
            amount: 250000.00,
            interestRate: 3.5,
            startDate: DateTime.now().subtract(const Duration(days: 1095)),
            dueDate: DateTime.now().add(const Duration(days: 365 * 25)),
            lender: 'Big Bank Inc.',
            description: 'Primary home mortgage',
            isFixed: true,
            minimumPayment: 1200.00,
            remainingPayments: 300,
          ),
          Liability(
            id: 'mock-2',
            userId: userId,
            name: 'Car Loan',
            type: 'Auto Loan',
            amount: 15000.00,
            interestRate: 4.2,
            startDate: DateTime.now().subtract(const Duration(days: 365)),
            dueDate: DateTime.now().add(const Duration(days: 365 * 4)),
            lender: 'Auto Finance Co.',
            description: 'Toyota Camry auto loan',
            isFixed: true,
            minimumPayment: 350.00,
            remainingPayments: 48,
          ),
          Liability(
            id: 'mock-3',
            userId: userId,
            name: 'Credit Card',
            type: 'Credit Card',
            amount: 4500.00,
            interestRate: 18.99,
            startDate: DateTime.now().subtract(const Duration(days: 180)),
            dueDate: DateTime.now().add(const Duration(days: 15)),
            lender: 'Credit Bank',
            description: 'Credit card debt',
            isFixed: false,
            minimumPayment: 100.00,
          ),
          Liability(
            id: 'mock-4',
            userId: userId,
            name: 'Student Loan',
            type: 'Student Loan',
            amount: 30000.00,
            interestRate: 5.8,
            startDate: DateTime.now().subtract(const Duration(days: 1825)),
            dueDate: DateTime.now().add(const Duration(days: 365 * 7)),
            lender: 'Student Loan Services',
            description: 'Federal student loan',
            isFixed: true,
            minimumPayment: 350.00,
            remainingPayments: 84,
          ),
          Liability(
            id: 'mock-5',
            userId: userId,
            name: 'Personal Loan',
            type: 'Personal Loan',
            amount: 8000.00,
            interestRate: 10.5,
            startDate: DateTime.now().subtract(const Duration(days: 90)),
            dueDate: DateTime.now().add(const Duration(days: 365 * 2)),
            lender: 'Lending Tree',
            description: 'Home renovation loan',
            isFixed: true,
            minimumPayment: 370.00,
            remainingPayments: 24,
          ),
        ];
        
        // Filter liabilities if a specific type is selected
        if (_selectedType != 'All') {
          _liabilities = _liabilities.where((liability) => liability.type == _selectedType).toList();
        }
        
        // Sort by amount (descending)
        _liabilities.sort((a, b) => b.amount.compareTo(a.amount));
        
        _isLoading = false;
        _useMockData = true;
        _errorMessage = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Using offline data - Server unavailable'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load liabilities: ${e.toString()}';
        _useMockData = true;
      });
    }
  }

  Future<void> _deleteLiability(String? liabilityId) async {
    if (liabilityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete liability with empty ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      // If using mock data or ID starts with 'mock', handle locally without API
      if (_useMockData || liabilityId.startsWith('mock')) {
        setState(() {
          _liabilities.removeWhere((liability) => liability.id == liabilityId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Liability deleted in offline mode'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Get token for authorization
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication required'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      
      // Delete liability via API
      try {
        final response = await _apiService.delete('liabilities/$liabilityId', token: token);
        
        if (response['success']) {
          setState(() {
            _liabilities.removeWhere((liability) => liability.id == liabilityId);
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Liability deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception(response['message'] ?? 'Unknown error');
        }
      } catch (apiError) {
        print('API error when deleting: $apiError');
        
        // Delete locally anyway as a fallback
        setState(() {
          _liabilities.removeWhere((liability) => liability.id == liabilityId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Server error - liability deleted locally'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error in _deleteLiability: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double _calculateTotalLiabilities() {
    return _liabilities.fold(0, (sum, liability) => sum + liability.amount);
  }

  String _getTypeIcon(String type) {
    switch (type) {
      case 'Mortgage':
        return '🏠';
      case 'Auto Loan':
        return '🚗';
      case 'Credit Card':
        return '💳';
      case 'Student Loan':
        return '🎓';
      case 'Personal Loan':
        return '💰';
      case 'Medical Debt':
        return '⚕️';
      default:
        return '📝';
    }
  }

  Future<void> _refreshLiabilities() async {
    await _loadLiabilities();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liabilities'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String type) {
              setState(() {
                _selectedType = type;
              });
              _refreshLiabilities();
            },
            itemBuilder: (BuildContext context) {
              return _liabilityTypes.map((String type) {
                return PopupMenuItem<String>(
                  value: type,
                  child: Row(
                    children: [
                      if (_selectedType == type)
                        const Icon(Icons.check, color: Colors.green)
                      else
                        const SizedBox(width: 24),
                      const SizedBox(width: 8),
                      Text(type),
                    ],
                  ),
                );
              }).toList();
            },
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshLiabilities,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Summary card
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                'Total Liabilities',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currencyFormatter.format(_calculateTotalLiabilities()),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // List of liabilities
                    Expanded(
                      child: _liabilities.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'No liabilities found',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Liability'),
                                    onPressed: () {
                                      Navigator.of(context).pushNamed('/add-liability').then((_) {
                                        _refreshLiabilities();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _refreshLiabilities,
                              child: ListView.builder(
                                itemCount: _liabilities.length,
                                itemBuilder: (context, index) {
                                  final liability = _liabilities[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                        child: Text(
                                          _getTypeIcon(liability.type),
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                      ),
                                      title: Text(liability.name),
                                      subtitle: Text('${liability.type} • ${DateFormat('MMM d, yyyy').format(liability.dueDate)}'),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            currencyFormatter.format(liability.amount),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.red,
                                            ),
                                          ),
                                          Text(
                                            '${liability.interestRate}% interest',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        showModalBottomSheet(
                                          context: context,
                                          builder: (ctx) => Container(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Center(
                                                  child: Text(
                                                    liability.name,
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const Divider(),
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text('Type: ${liability.type}'),
                                                    Text('Amount: ${currencyFormatter.format(liability.amount)}'),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text('Interest Rate: ${liability.interestRate}%'),
                                                    Text('Fixed: ${liability.isFixed ? 'Yes' : 'No'}'),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text('Start Date: ${DateFormat('MMM d, yyyy').format(liability.startDate)}'),
                                                    Text('Due Date: ${DateFormat('MMM d, yyyy').format(liability.dueDate)}'),
                                                  ],
                                                ),
                                                if (liability.lender != null) ...[
                                                  const SizedBox(height: 8),
                                                  Text('Lender: ${liability.lender}'),
                                                ],
                                                if (liability.minimumPayment != null) ...[
                                                  const SizedBox(height: 8),
                                                  Text('Minimum Payment: ${currencyFormatter.format(liability.minimumPayment)}'),
                                                ],
                                                if (liability.remainingPayments != null) ...[
                                                  const SizedBox(height: 8),
                                                  Text('Remaining Payments: ${liability.remainingPayments}'),
                                                ],
                                                if (liability.description != null) ...[
                                                  const SizedBox(height: 16),
                                                  const Text(
                                                    'Description:',
                                                    style: TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(liability.description!),
                                                ],
                                                const SizedBox(height: 24),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                  children: [
                                                    ElevatedButton.icon(
                                                      icon: const Icon(Icons.edit),
                                                      label: const Text('Edit'),
                                                      onPressed: () {
                                                        Navigator.of(ctx).pop();
                                                        Navigator.of(context).pushNamed(
                                                          '/edit-liability',
                                                          arguments: liability,
                                                        ).then((_) {
                                                          _refreshLiabilities();
                                                        });
                                                      },
                                                    ),
                                                    TextButton.icon(
                                                      icon: const Icon(Icons.delete, color: Colors.red),
                                                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                                                      onPressed: () {
                                                        Navigator.of(ctx).pop();
                                                        showDialog(
                                                          context: context,
                                                          builder: (context) => AlertDialog(
                                                            title: const Text('Delete Liability'),
                                                            content: const Text('Are you sure you want to delete this liability?'),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () => Navigator.of(context).pop(),
                                                                child: const Text('Cancel'),
                                                              ),
                                                              TextButton(
                                                                onPressed: () {
                                                                  Navigator.of(context).pop();
                                                                  _deleteLiability(liability.id);
                                                                },
                                                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamed('/add-liability').then((_) {
            _refreshLiabilities();
          });
        },
        tooltip: 'Add Liability',
        child: const Icon(Icons.add),
      ),
    );
  }
} 