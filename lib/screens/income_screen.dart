import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:convert';
import '../models/income_model.dart';
import '../services/api_service.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({Key? key}) : super(key: key);

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  bool _isLoading = true;
  List<Income> _incomes = [];
  String? _errorMessage;
  bool _useMockData = false;
  final ApiService _apiService = ApiService();
  final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  String _selectedPeriod = 'This Month';
  final List<String> _filterPeriods = ['This Month', 'Last Month', 'This Year', 'All Time'];

  @override
  void initState() {
    super.initState();
    _loadSelectedPeriod().then((_) => _loadIncomes());
  }

  Future<void> _loadSelectedPeriod() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final period = prefs.getString('selectedPeriod');
      
      if (period != null && _filterPeriods.contains(period)) {
        setState(() {
          _selectedPeriod = period;
        });
      }
    } catch (e) {
      print('Error loading selected period: $e');
    }
  }

  Future<void> _saveSelectedPeriod(String period) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedPeriod', period);
    } catch (e) {
      print('Error saving selected period: $e');
    }
  }

  String _getDateRangeText() {
    final now = DateTime.now();
    final dateFormat = DateFormat('MMM d, y');
    
    if (_selectedPeriod == 'This Month') {
      final startDate = DateTime(now.year, now.month, 1);
      final endDate = DateTime(now.year, now.month + 1, 0);
      return '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}';
    } else if (_selectedPeriod == 'Last Month') {
      final startDate = DateTime(now.year, now.month - 1, 1);
      final endDate = DateTime(now.year, now.month, 0);
      return '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}';
    } else if (_selectedPeriod == 'This Year') {
      final startDate = DateTime(now.year, 1, 1);
      final endDate = DateTime(now.year, 12, 31);
      return '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}';
    } else {
      return 'All Time';
    }
  }

  Future<void> _loadIncomes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // First, load any locally stored incomes
      final prefs = await SharedPreferences.getInstance();
      final localIncomeStrings = prefs.getStringList('offline_incomes') ?? [];
      
      Map<String, Income> incomeMap = {};
      
      // Parse locally stored incomes first
      if (localIncomeStrings.isNotEmpty) {
        for (final incomeString in localIncomeStrings) {
          try {
            final json = jsonDecode(incomeString);
            final income = Income.fromJson(json);
            // Handle null safety properly
            if (income.id != null) {
              incomeMap[income.id!] = income;
              print('Loaded local income: ${income.source}');
            }
          } catch (e) {
            print('Error parsing local income: $e');
          }
        }
      }
      
      // Continue with API loading
      final token = await _getToken();
      
      if (token == null) {
        throw Exception('Authentication required');
      }
      
      // Try to get the date range based on selected period
      DateTime? startDate;
      DateTime? endDate;
      
      final now = DateTime.now();
      if (_selectedPeriod == 'This Month') {
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0);
      } else if (_selectedPeriod == 'Last Month') {
        startDate = DateTime(now.year, now.month - 1, 1);
        endDate = DateTime(now.year, now.month, 0);
      } else if (_selectedPeriod == 'This Year') {
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year + 1, 1, 0);
      } else {
        // All Time
        startDate = DateTime(2000); // Far past
        endDate = DateTime.now().add(const Duration(days: 1)); // Tomorrow
      }
      
      // Try to fetch from API
      try {
        final response = await _apiService.get('incomes', token: token);
        
        // Handle different API response formats
        List<dynamic> incomesData = [];
        
        if (response is List) {
          // Direct array format
          incomesData = response;
        } else if (response['data'] != null && response['data'] is List) {
          // Wrapped format with success and data fields
          incomesData = response['data'];
        } else if (response['success'] == false) {
          throw Exception(response['message'] ?? 'Failed to load incomes');
        }
        
        // Process API incomes and add them to the map
        // (but don't overwrite local ones with same ID)
        for (final incomeData in incomesData) {
          final income = Income.fromJson(incomeData);
          if (income.id != null && !incomeMap.containsKey(income.id)) {
            incomeMap[income.id!] = income;
          }
        }
        _useMockData = false;
      } catch (apiError) {
        print('API error when loading incomes: $apiError');
        // If API call fails completely, we'll continue with local data
        // and load mockIncomes only if we don't have any data yet
        if (incomeMap.isEmpty) {
          _loadMockIncomes();
          return;
        }
      }
      
      // Convert map back to list
      List<Income> allIncomes = incomeMap.values.toList();
      
      // Sort by date, most recent first
      allIncomes.sort((a, b) => b.date.compareTo(a.date));
      
      // Filter by date if needed
      if (startDate != null && endDate != null) {
        allIncomes = allIncomes.where((income) {
          return income.date.isAfter(startDate!.subtract(const Duration(days: 1))) && 
                 income.date.isBefore(endDate!.add(const Duration(days: 1)));
        }).toList();
      }
      
      setState(() {
        _incomes = allIncomes;
        _isLoading = false;
        _errorMessage = null;
        _useMockData = localIncomeStrings.isNotEmpty && _incomes.isEmpty;
      });
    } catch (e) {
      print('Error loading incomes: $e');
      setState(() {
        _errorMessage = 'Failed to load incomes: ${e.toString().split(':').first}';
        _isLoading = false;
        
        // Load mock data if everything else fails
        if (_incomes.isEmpty) {
          _loadMockIncomes();
        }
      });
    }
  }

  // Helper method to get token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadMockIncomes() async {
    // Generate date range based on selected period
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;
    
    if (_selectedPeriod == 'This Month') {
      startDate = DateTime(now.year, now.month, 1);
    } else if (_selectedPeriod == 'Last Month') {
      startDate = DateTime(now.year, now.month - 1, 1);
      endDate = DateTime(now.year, now.month, 0);
    } else if (_selectedPeriod == 'This Year') {
      startDate = DateTime(now.year, 1, 1);
    } else { // All Time
      startDate = DateTime(2000); // Some date far in the past
    }
    
    // Generate mock incomes
    final mockIncomes = [
      Income(
        id: 'mock-1',
        userId: 'mock-user',
        source: 'Salary',
        amount: 5000.00,
        category: 'Employment',
        date: DateTime.now().subtract(const Duration(days: 5)),
        isRecurring: true,
        frequency: 'monthly',
      ),
      Income(
        id: 'mock-2',
        userId: 'mock-user',
        source: 'Freelance Work',
        amount: 1200.00,
        category: 'Side Gig',
        date: DateTime.now().subtract(const Duration(days: 10)),
        isRecurring: false,
        frequency: 'one-time',
        description: 'Website development project',
      ),
      Income(
        id: 'mock-3',
        userId: 'mock-user',
        source: 'Dividend Payment',
        amount: 350.00,
        category: 'Investments',
        date: DateTime.now().subtract(const Duration(days: 15)),
        isRecurring: true,
        frequency: 'quarterly',
        description: 'Stock dividends',
      ),
    ];
    
    // Filter by date if needed
    List<Income> filteredIncomes = mockIncomes;
    if (startDate != null && endDate != null) {
      filteredIncomes = mockIncomes.where((income) {
        return income.date.isAfter(startDate) && income.date.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();
    }
    
    // Sort by date
    filteredIncomes.sort((a, b) => b.date.compareTo(a.date));
    
    setState(() {
      _incomes = filteredIncomes;
      _isLoading = false;
      _useMockData = true;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Using offline data - API unavailable'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _deleteIncome(String? id) async {
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete income with empty ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Optimistic update - delete immediately from UI
    final deletedIndex = _incomes.indexWhere((income) => income.id == id);
    Income? deletedIncome;
    
    if (deletedIndex != -1) {
      deletedIncome = _incomes[deletedIndex];
      setState(() {
        _incomes.removeAt(deletedIndex);
      });
    }
    
    try {
      // If it's a mock or local ID, just handle locally
      if (_useMockData || id.startsWith('mock') || id.startsWith('local')) {
        // Also remove from local storage
        await _deleteLocalIncome(id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Income deleted (offline mode)'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        // Restore the income if we can't proceed
        if (deletedIncome != null && deletedIndex >= 0) {
          setState(() {
            _incomes.insert(deletedIndex, deletedIncome!);
          });
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication required - please log in'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      
      try {
        // Call the API to delete
        final response = await _apiService.delete('incomes/$id', token: token);
        
        // Consider it a success if we don't have an explicit failure
        if (response['success'] == false) {
          throw Exception(response['message'] ?? 'Failed to delete on server');
        }
        
        // Also remove from local storage
        await _deleteLocalIncome(id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Income deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (apiError) {
        print('API error when deleting income: $apiError');
        
        // Just mark as deleted locally
        await _deleteLocalIncome(id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete on server - removed locally'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _deleteIncome(id),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error deleting income: $e');
      
      // Restore the income if deletion fails
      if (deletedIncome != null) {
        setState(() {
          if (deletedIndex >= 0 && deletedIndex <= _incomes.length) {
            _incomes.insert(deletedIndex, deletedIncome!);
          } else {
            _incomes.add(deletedIncome!);
            _incomes.sort((a, b) => b.date.compareTo(a.date));
          }
        });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete income: ${e.toString().split(':').first}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Delete income from local storage
  Future<void> _deleteLocalIncome(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localIncomes = prefs.getStringList('offline_incomes') ?? [];
      
      final filteredIncomes = localIncomes.where((incomeJson) {
        try {
          final Map<String, dynamic> income = jsonDecode(incomeJson);
          final incomeId = income['_id'] ?? income['id'];
          return incomeId != id;
        } catch (e) {
          print('Error parsing income JSON: $e');
          return true; // Keep entries that can't be parsed
        }
      }).toList();
      
      await prefs.setStringList('offline_incomes', filteredIncomes);
      print('Income removed from local storage: $id');
    } catch (e) {
      print('Error removing income from local storage: $e');
    }
  }

  Future<void> _refreshIncomes() async {
    await _loadIncomes();
  }

  String _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'employment':
      case 'salary':
        return '💼';
      case 'investments':
      case 'dividend':
        return '📈';
      case 'side gig':
      case 'freelance':
        return '💻';
      case 'rental':
        return '🏠';
      case 'gifts':
        return '🎁';
      case 'other':
        return '💰';
      default:
        return '💵';
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalIncome = 0;
    for (var income in _incomes) {
      totalIncome += income.amount;
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Income'),
        actions: [
          // Period selector
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: DropdownButton<String>(
              value: _selectedPeriod,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              elevation: 16,
              style: const TextStyle(color: Colors.white),
              underline: Container(height: 0),
              onChanged: (String? value) async {
                if (value != null) {
                  setState(() {
                    _selectedPeriod = value;
                  });
                  await _saveSelectedPeriod(value);
                  _loadIncomes();
                }
              },
              dropdownColor: Theme.of(context).primaryColor,
              items: _filterPeriods.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, 
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
            ),
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
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadIncomes,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadIncomes,
                  child: Column(
                    children: [
                      // Summary card
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Income ($_selectedPeriod)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currencyFormatter.format(totalIncome),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _getDateRangeText(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // List of incomes
                      Expanded(
                        child: _incomes.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet,
                                      size: 80,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No income entries found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Tap the + button to add your first income',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _incomes.length,
                                itemBuilder: (context, index) {
                                  final income = _incomes[index];
                                  return _buildIncomeItem(income);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add-income').then((_) => _loadIncomes());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildIncomeItem(Income income) {
    return Dismissible(
      key: Key(income.id ?? 'unknown-${income.date.toString()}'),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Income'),
              content: const Text('Are you sure you want to delete this income?'),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: const Text('Delete'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        _deleteIncome(income.id);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Text(
              _getCategoryIcon(income.category),
              style: const TextStyle(fontSize: 24),
            ),
          ),
          title: Text(income.source),
          subtitle: Text(
            '${income.category} • ${DateFormat('MMM d, yyyy').format(income.date)}' +
            (income.isRecurring ? ' • ${income.frequency}' : ''),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                income.getFormattedAmount(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green,
                ),
              ),
              if (income.isRecurring)
                const Text(
                  'Recurring',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          income.source,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          income.getFormattedAmount(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Category:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                income.category,
                                style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Date:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                income.getFormattedDate(),
                                style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recurring:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                income.isRecurring ? 'Yes' : 'No',
                                style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                              ),
                            ],
                          ),
                        ),
                        if (income.isRecurring)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Frequency:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  income.frequency,
                                  style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (income.description != null && income.description!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Description:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        income.description!,
                        style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            Navigator.of(context)
                                .pushNamed('/edit-income', arguments: income)
                                .then((_) {
                              _loadIncomes();
                            });
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text('Delete', style: TextStyle(color: Colors.red)),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Income'),
                                content: const Text('Are you sure you want to delete this income?'),
                                actions: [
                                  TextButton(
                                    child: const Text('Cancel'),
                                    onPressed: () => Navigator.of(ctx).pop(),
                                  ),
                                  TextButton(
                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      _deleteIncome(income.id);
                                    },
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
      ),
    );
  }
} 