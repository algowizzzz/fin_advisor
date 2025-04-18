import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:convert';
import '../models/expense_model.dart';
import '../services/api_service.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({Key? key}) : super(key: key);

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  bool _isLoading = true;
  List<Expense> _expenses = [];
  String? _errorMessage;
  bool _useMockData = false;
  final ApiService _apiService = ApiService();
  final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  String _selectedPeriod = 'This Month';
  final List<String> _filterPeriods = ['This Month', 'Last Month', 'This Year', 'All Time'];

  @override
  void initState() {
    super.initState();
    _loadSelectedPeriod().then((_) => _loadExpenses());
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

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // First, load any locally stored expenses
      final prefs = await SharedPreferences.getInstance();
      final localExpenseStrings = prefs.getStringList('offline_expenses') ?? [];
      
      Map<String, Expense> expenseMap = {};
      
      // Parse locally stored expenses first
      if (localExpenseStrings.isNotEmpty) {
        for (final expenseString in localExpenseStrings) {
          try {
            final json = jsonDecode(expenseString);
            final expense = Expense.fromJson(json);
            // Handle null safety properly
            if (expense.id != null) {
              expenseMap[expense.id!] = expense;
              print('Loaded local expense: ${expense.title}');
            }
          } catch (e) {
            print('Error parsing local expense: $e');
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
        final response = await _apiService.get('expenses', token: token);
        if (response['success']) {
          final List<dynamic> expensesData = response['data'];
          
          // Process API expenses and add them to the map
          // (but don't overwrite local ones with same ID)
          for (final expenseData in expensesData) {
            final expense = Expense.fromJson(expenseData);
            if (expense.id != null && !expenseMap.containsKey(expense.id)) {
              expenseMap[expense.id!] = expense;
            }
          }
        }
      } catch (apiError) {
        print('API error when loading expenses: $apiError');
        // Continue with local data if API fails
      }
      
      // Convert map back to list
      List<Expense> allExpenses = expenseMap.values.toList();
      
      // Sort by date, most recent first
      allExpenses.sort((a, b) => b.date.compareTo(a.date));
      
      // Filter by date if needed
      if (startDate != null && endDate != null) {
        allExpenses = allExpenses.where((expense) {
          return expense.date.isAfter(startDate!.subtract(const Duration(days: 1))) && 
                 expense.date.isBefore(endDate!.add(const Duration(days: 1)));
        }).toList();
      }
      
      setState(() {
        _expenses = allExpenses;
        _isLoading = false;
        _errorMessage = null;
        _useMockData = localExpenseStrings.isNotEmpty && _expenses.isEmpty;
      });
    } catch (e) {
      print('Error loading expenses: $e');
      setState(() {
        _errorMessage = 'Failed to load expenses: ${e.toString().split(':').first}';
        _isLoading = false;
        
        // Load mock data if everything else fails
        if (_expenses.isEmpty) {
          _loadMockExpenses();
        }
      });
    }
  }

  // Helper method to get token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadMockExpenses() async {
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
    
    // Generate mock expenses
    final mockExpenses = [
      Expense(
        id: 'mock-1',
        userId: 'mock-user',
        title: 'Groceries',
        amount: 120.50,
        category: 'Food',
        date: DateTime.now().subtract(const Duration(days: 2)),
        isRecurring: false,
        frequency: 'Monthly',
      ),
      Expense(
        id: 'mock-2',
        userId: 'mock-user',
        title: 'Netflix',
        amount: 15.99,
        category: 'Entertainment',
        date: DateTime.now().subtract(const Duration(days: 5)),
        isRecurring: true,
        frequency: 'Monthly',
        durationMonths: 12,
      ),
      Expense(
        id: 'mock-3',
        userId: 'mock-user',
        title: 'Gas',
        amount: 45.30,
        category: 'Transportation',
        date: DateTime.now().subtract(const Duration(days: 10)),
        isRecurring: false,
        frequency: 'Monthly',
      ),
      Expense(
        id: 'mock-4',
        userId: 'mock-user',
        title: 'Rent',
        amount: 1200.00,
        category: 'Housing',
        date: DateTime.now().subtract(const Duration(days: 15)),
        isRecurring: true,
        frequency: 'Monthly',
        durationMonths: 12,
        description: 'Monthly apartment rent',
      ),
      Expense(
        id: 'mock-5',
        userId: 'mock-user',
        title: 'Dinner',
        amount: 85.20,
        category: 'Food',
        date: DateTime.now().subtract(const Duration(days: 20)),
        isRecurring: false,
        frequency: 'Monthly',
        description: 'Dinner with friends',
      ),
      // Add some expenses from previous months for filtering
      Expense(
        id: 'mock-6',
        userId: 'mock-user',
        title: 'Previous Month Rent',
        amount: 1200.00,
        category: 'Housing',
        date: DateTime.now().subtract(const Duration(days: 45)),
        isRecurring: true,
        frequency: 'Monthly',
        durationMonths: 12,
      ),
      Expense(
        id: 'mock-7',
        userId: 'mock-user',
        title: 'Previous Month Utilities',
        amount: 150.75,
        category: 'Utilities',
        date: DateTime.now().subtract(const Duration(days: 50)),
        isRecurring: false,
        frequency: 'Monthly',
      ),
    ];
    
    // Filter based on date range
    final filteredExpenses = mockExpenses.where((expense) {
      return expense.date.isAfter(startDate) && 
             expense.date.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
    
    // Sort by date descending
    filteredExpenses.sort((a, b) => b.date.compareTo(a.date));
    
    // Also load any local changes from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final localExpenses = prefs.getStringList('offline_expenses') ?? [];
      
      // Create a map of mock expenses by ID for easy lookup/replacement
      final Map<String, Expense> expenseMap = {};
      
      // Add all filtered expenses to the map
      for (var e in filteredExpenses) {
        if (e.id != null) {
          expenseMap[e.id!] = e;
        }
      }
      
      // Override with any local changes or add new local expenses
      for (final expenseJson in localExpenses) {
        try {
          final expense = Expense.fromJson(jsonDecode(expenseJson));
          
          // Check if it's within our date range and has a valid ID
          if (expense.id != null && 
              expense.date.isAfter(startDate) && 
              expense.date.isBefore(endDate.add(const Duration(days: 1)))) {
            expenseMap[expense.id!] = expense;
          }
        } catch (e) {
          print('Error parsing local expense: $e');
        }
      }
      
      // Convert back to list and sort
      final combinedExpenses = expenseMap.values.toList();
      combinedExpenses.sort((a, b) => b.date.compareTo(a.date));
      
      setState(() {
        _expenses = combinedExpenses;
        _isLoading = false;
        _useMockData = true;
      });
    } catch (e) {
      print('Error loading local expenses: $e');
      setState(() {
        _expenses = filteredExpenses;
        _isLoading = false;
        _useMockData = true;
      });
    }
  }

  Future<void> _deleteExpense(String? expenseId) async {
    if (expenseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete expense with empty ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      // If using mock data or ID starts with 'mock', handle locally without API
      if (_useMockData || expenseId.startsWith('mock')) {
        setState(() {
          _expenses.removeWhere((expense) => expense.id == expenseId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense deleted in offline mode'),
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
      
      // Delete expense via API
      try {
        final response = await _apiService.delete('expenses/$expenseId', token: token);
        
        if (response['success']) {
          setState(() {
            _expenses.removeWhere((expense) => expense.id == expenseId);
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception(response['message'] ?? 'Failed to delete expense');
        }
      } catch (apiError) {
        print('API error when deleting: $apiError');
        
        // If API fails, still delete locally
        setState(() {
          _expenses.removeWhere((expense) => expense.id == expenseId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error - expense removed locally'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error deleting expense: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().split(':').first}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshExpenses() async {
    setState(() {
      _isLoading = true;
    });
    await _loadExpenses();
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'housing':
        return Colors.blue;
      case 'food':
        return Colors.green;
      case 'transportation':
        return Colors.orange;
      case 'utilities':
        return Colors.purple;
      case 'entertainment':
        return Colors.red;
      case 'health':
        return Colors.pink;
      case 'education':
        return Colors.teal;
      case 'personal':
        return Colors.indigo;
      case 'debt':
        return Colors.deepOrange;
      case 'savings':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'housing':
        return Icons.home;
      case 'food':
        return Icons.restaurant;
      case 'transportation':
        return Icons.directions_car;
      case 'utilities':
        return Icons.power;
      case 'entertainment':
        return Icons.movie;
      case 'health':
        return Icons.favorite;
      case 'education':
        return Icons.school;
      case 'personal':
        return Icons.person;
      case 'debt':
        return Icons.money_off;
      case 'savings':
        return Icons.savings;
      default:
        return Icons.attach_money;
    }
  }

  void _showExpenseOptions(BuildContext context, Expense expense) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Expense'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(
                  context, 
                  '/edit-expense',
                  arguments: expense,
                ).then((_) => _loadExpenses());
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Expense', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteExpense(context, expense);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteExpense(BuildContext context, Expense expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "${expense.title}"?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteExpense(expense.id);
            },
          ),
        ],
      ),
    );
  }

  void _showExpenseDetails(BuildContext context, Expense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getCategoryColor(expense.category),
                  radius: 20,
                  child: Icon(
                    _getCategoryIcon(expense.category),
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    expense.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  currencyFormatter.format(expense.amount),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailItem(Icons.calendar_today, 'Date', DateFormat('MMMM d, yyyy').format(expense.date)),
            _buildDetailItem(Icons.category, 'Category', expense.category),
            if (expense.isRecurring)
              _buildDetailItem(
                Icons.repeat, 
                'Recurring', 
                '${expense.frequency}${expense.durationMonths != null ? ' (${expense.durationMonths} months)' : ''}',
                valueColor: Colors.blue,
              ),
            if (expense.description != null && expense.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                expense.description!,
                style: const TextStyle(fontSize: 16),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(
                        context, 
                        '/edit-expense',
                        arguments: expense,
                      ).then((_) => _loadExpenses());
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDeleteExpense(context, expense);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalExpenses = 0;
    for (var expense in _expenses) {
      totalExpenses += expense.amount;
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
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
                  _loadExpenses();
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
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadExpenses,
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
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                        onPressed: _loadExpenses,
                      ),
                    ],
                  ),
                )
          : _expenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.money_off, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No expenses found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Expense'),
                        onPressed: () async {
                          final result = await Navigator.of(context).pushNamed('/add-expense');
                          if (result == true) {
                            _loadExpenses();
                          }
                        },
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadExpenses,
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
                                  'Total Expenses ($_selectedPeriod)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currencyFormatter.format(totalExpenses),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
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
                      Expanded(
                        child: _expenses.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      size: 80,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No expense entries found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Tap the + button to add your first expense',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(8.0),
                                itemCount: _expenses.length,
                                itemBuilder: (context, index) {
                                  final expense = _expenses[index];
                                  return Dismissible(
                                    key: Key(expense.id ?? 'unknown-${expense.date.toString()}'),
                                    background: Container(
                                      color: Colors.red,
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    direction: DismissDirection.endToStart,
                                    confirmDismiss: (direction) async {
                                      return await showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Confirm Delete'),
                                          content: Text(
                                            'Are you sure you want to delete "${expense.title}"?'
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    onDismissed: (direction) {
                                      _deleteExpense(expense.id);
                                    },
                                    child: Card(
                                      elevation: 1,
                                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: _getCategoryColor(expense.category),
                                          child: Icon(
                                            _getCategoryIcon(expense.category),
                                            color: Colors.white,
                                          ),
                                        ),
                                        title: Text(expense.title),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(expense.category),
                                            Text(
                                              DateFormat('MMM d, y').format(expense.date),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                            if (expense.isRecurring)
                                              Text(
                                                'Recurring (${expense.frequency})',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontStyle: FontStyle.italic,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              currencyFormatter.format(expense.amount),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.more_vert),
                                              onPressed: () {
                                                _showExpenseOptions(context, expense);
                                              },
                                            ),
                                          ],
                                        ),
                                        onTap: () {
                                          _showExpenseDetails(context, expense);
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add-expense').then((_) => _loadExpenses());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
} 