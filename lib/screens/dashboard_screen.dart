import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/income_model.dart';
import '../models/expense_model.dart';
import '../models/asset_model.dart';
import '../models/liability_model.dart';
import '../models/goal_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final percentFormatter = NumberFormat.percentPattern('en_US');
  
  bool _isLoading = true;
  String? _errorMessage;
  String _userName = 'User';
  String _userEmail = '';
  bool _isConnected = false;
  bool _isDatabaseConnected = false;
  bool _isAuthenticated = false;
  
  // Time period filtering
  String _selectedPeriod = 'This Month';
  final List<String> _filterPeriods = ['This Month', 'Last Month', 'This Year', 'All Time'];
  
  // Data
  List<Income> _incomes = [];
  List<Expense> _expenses = [];
  List<Asset> _assets = [];
  List<Liability> _liabilities = [];
  List<Goal> _goals = [];
  
  // Filtered data
  List<Income> _filteredIncomes = [];
  List<Expense> _filteredExpenses = [];
  
  // Summary data
  double _totalIncome = 0;
  double _totalExpenses = 0;
  double _totalAssets = 0;
  double _totalLiabilities = 0;
  double _netWorth = 0;
  
  // Chart data
  Map<String, double> _incomeByCategory = {};
  Map<String, double> _expensesByCategory = {};
  
  // Add the touchedIndex state variable after other state variables like _totalIncome
  int _touchedIndex = -1;
  
  // Financial health score variables
  int _financialHealthScore = 72; // Default starting score
  String _financialHealthMessage = 'Your finances are in good shape, but there\'s room for improvement';
  
  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadSelectedPeriod();
    _loadAllData();
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

  void _showConnectionStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusRow('Backend', _isConnected),
            _buildStatusRow('Database', _isDatabaseConnected),
            _buildStatusRow('Authentication', _isAuthenticated),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _checkConnection();
            },
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.cancel,
            color: status ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
  
  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final token = await _getToken();
      
      if (token == null) {
        setState(() {
          _errorMessage = 'Authentication required';
          _isLoading = false;
        });
        return;
      }
      
      // Load all data in parallel
      await Future.wait([
        _loadIncomes(token),
        _loadExpenses(token),
        _loadAssets(token),
        _loadLiabilities(token),
        _loadGoals(token),
      ]);
      
      // Calculate summary data
      _calculateSummaryData();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString().split(':').first}';
        _isLoading = false;
      });
    }
  }
  
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
  
  Future<void> _loadIncomes(String token) async {
    try {
      final response = await _apiService.get('incomes', token: token);
      
      List<dynamic> incomesData = [];
      
      if (response is List) {
        incomesData = response;
      } else if (response['data'] != null && response['data'] is List) {
        incomesData = response['data'];
      } else if (response['success'] == false) {
        throw Exception(response['message'] ?? 'Failed to load incomes');
      }
      
      final incomes = incomesData.map((data) => Income.fromJson(data)).toList();
      
      if (mounted) {
        setState(() {
          _incomes = incomes;
        });
      }
    } catch (e) {
      print('API error when loading incomes: $e');
      // Use empty list if loading fails
      if (mounted) {
        setState(() {
          _incomes = [];
        });
      }
    }
  }
  
  Future<void> _loadExpenses(String token) async {
    try {
      final response = await _apiService.get('expenses', token: token);
      
      if (response['success']) {
        final List<dynamic> expensesData = response['data'];
        final expenses = expensesData.map((data) => Expense.fromJson(data)).toList();
        
        if (mounted) {
          setState(() {
            _expenses = expenses;
          });
        }
      }
    } catch (e) {
      print('API error when loading expenses: $e');
      // Use empty list if loading fails
      if (mounted) {
        setState(() {
          _expenses = [];
        });
      }
    }
  }
  
  Future<void> _loadAssets(String token) async {
    try {
      final response = await _apiService.get('assets', token: token);
      
      if (response['success']) {
        final List<dynamic> assetsData = response['data'];
        final assets = assetsData.map((data) => Asset.fromJson(data)).toList();
        
        if (mounted) {
          setState(() {
            _assets = assets;
          });
        }
      }
    } catch (e) {
      print('API error when loading assets: $e');
      // Use empty list if loading fails
      if (mounted) {
        setState(() {
          _assets = [];
        });
      }
    }
  }
  
  Future<void> _loadLiabilities(String token) async {
    try {
      final response = await _apiService.get('liabilities', token: token);
      
      if (response['success']) {
        final List<dynamic> liabilitiesData = response['data'];
        final liabilities = liabilitiesData.map((data) => Liability.fromJson(data)).toList();
        
        if (mounted) {
          setState(() {
            _liabilities = liabilities;
          });
        }
      }
    } catch (e) {
      print('API error when loading liabilities: $e');
      // Use empty list if loading fails
      if (mounted) {
        setState(() {
          _liabilities = [];
        });
      }
    }
  }
  
  Future<void> _loadGoals(String token) async {
    try {
      final response = await _apiService.get('goals', token: token);
      
      if (response['success']) {
        final List<dynamic> goalsData = response['data'];
        final goals = goalsData.map((data) => Goal.fromJson(data)).toList();
        
        if (mounted) {
          setState(() {
            _goals = goals;
          });
        }
      }
    } catch (e) {
      print('API error when loading goals: $e');
      // Use empty list if loading fails
      if (mounted) {
        setState(() {
          _goals = [];
        });
      }
    }
  }
  
  void _calculateSummaryData() {
    // Filter incomes and expenses based on selected period
    _filterDataByPeriod();
    
    // Calculate total income from filtered data
    _totalIncome = _filteredIncomes.fold(0, (sum, income) => sum + income.amount);
    
    // Calculate total expenses from filtered data
    _totalExpenses = _filteredExpenses.fold(0, (sum, expense) => sum + expense.amount);
    
    // Calculate total assets
    _totalAssets = _assets.fold(0, (sum, asset) => sum + asset.value);
    
    // Calculate total liabilities
    _totalLiabilities = _liabilities.fold(0, (sum, liability) => sum + liability.amount);
    
    // Calculate net worth
    _netWorth = _totalAssets - _totalLiabilities;
    
    // Calculate financial health score
    _calculateFinancialHealthScore();
    
    // Group incomes by category using filtered data
    _incomeByCategory = {};
    for (final income in _filteredIncomes) {
      final category = income.category;
      if (_incomeByCategory.containsKey(category)) {
        _incomeByCategory[category] = _incomeByCategory[category]! + income.amount;
      } else {
        _incomeByCategory[category] = income.amount;
      }
    }
    
    // Group expenses by category using filtered data
    _expensesByCategory = {};
    for (final expense in _filteredExpenses) {
      final category = expense.category;
      if (_expensesByCategory.containsKey(category)) {
        _expensesByCategory[category] = _expensesByCategory[category]! + expense.amount;
      } else {
        _expensesByCategory[category] = expense.amount;
      }
    }
  }
  
  // Calculate financial health score based on multiple factors
  void _calculateFinancialHealthScore() {
    int cashFlowScore = 0;
    int netWorthScore = 0;
    int savingsScore = 0;
    int debtScore = 0;
    
    // 1. Cash Flow Score (0-40 points)
    // Income to expense ratio
    if (_totalExpenses > 0) {
      double incomeExpenseRatio = _totalIncome / _totalExpenses;
      if (incomeExpenseRatio >= 2.0) {
        cashFlowScore = 40; // Excellent: Income more than double expenses
      } else if (incomeExpenseRatio >= 1.5) {
        cashFlowScore = 35; // Very good
      } else if (incomeExpenseRatio >= 1.2) {
        cashFlowScore = 30; // Good
      } else if (incomeExpenseRatio >= 1.0) {
        cashFlowScore = 20; // Fair: Income equals or slightly exceeds expenses
      } else if (incomeExpenseRatio >= 0.8) {
        cashFlowScore = 10; // Poor: Expenses exceed income by up to 20%
      } else {
        cashFlowScore = 0; // Critical: Expenses exceed income by more than 20%
      }
    } else if (_totalIncome > 0) {
      cashFlowScore = 40; // If no expenses but has income
    }
    
    // 2. Net Worth Score (0-30 points)
    if (_totalLiabilities > 0) {
      double assetLiabilityRatio = _totalAssets / _totalLiabilities;
      if (assetLiabilityRatio >= 5.0) {
        netWorthScore = 30; // Excellent: Assets are 5+ times liabilities
      } else if (assetLiabilityRatio >= 3.0) {
        netWorthScore = 25; // Very good
      } else if (assetLiabilityRatio >= 2.0) {
        netWorthScore = 20; // Good
      } else if (assetLiabilityRatio >= 1.0) {
        netWorthScore = 15; // Fair: Assets equal or slightly exceed liabilities
      } else if (assetLiabilityRatio >= 0.5) {
        netWorthScore = 10; // Poor: Liabilities exceed assets but not by 2x
      } else {
        netWorthScore = 0; // Critical: Liabilities more than double assets
      }
    } else if (_totalAssets > 0) {
      netWorthScore = 30; // If no liabilities but has assets
    }
    
    // 3. Savings Score (0-20 points)
    // Estimate savings as income minus expenses
    double savingsAmount = _totalIncome - _totalExpenses;
    if (_totalIncome > 0) {
      double savingsRate = savingsAmount / _totalIncome;
      if (savingsRate >= 0.3) {
        savingsScore = 20; // Excellent: Saving 30%+ of income
      } else if (savingsRate >= 0.2) {
        savingsScore = 15; // Very good
      } else if (savingsRate >= 0.1) {
        savingsScore = 10; // Good
      } else if (savingsRate >= 0.05) {
        savingsScore = 5; // Fair: Saving 5-10% of income
      } else if (savingsRate >= 0) {
        savingsScore = 3; // Poor: Saving 0-5% of income
      } else {
        savingsScore = 0; // Critical: Not saving at all
      }
    }
    
    // 4. Debt Score (0-10 points)
    if (_totalIncome > 0 && _totalLiabilities > 0) {
      // Estimate monthly debt payment as 1% of total liabilities
      double estimatedMonthlyDebt = _totalLiabilities * 0.01;
      double debtToIncomeRatio = estimatedMonthlyDebt / (_totalIncome / 12);
      
      if (debtToIncomeRatio <= 0.1) {
        debtScore = 10; // Excellent: Debt payments less than 10% of monthly income
      } else if (debtToIncomeRatio <= 0.2) {
        debtScore = 8; // Very good
      } else if (debtToIncomeRatio <= 0.3) {
        debtScore = 6; // Good
      } else if (debtToIncomeRatio <= 0.4) {
        debtScore = 4; // Fair
      } else if (debtToIncomeRatio <= 0.5) {
        debtScore = 2; // Poor
      } else {
        debtScore = 0; // Critical: Debt payments exceed 50% of monthly income
      }
    } else if (_totalLiabilities == 0) {
      debtScore = 10; // No debt
    }
    
    // Calculate total score (0-100)
    _financialHealthScore = cashFlowScore + netWorthScore + savingsScore + debtScore;
    
    // Set the message based on the score
    if (_financialHealthScore >= 90) {
      _financialHealthMessage = 'Your finances are in excellent shape';
    } else if (_financialHealthScore >= 75) {
      _financialHealthMessage = 'Your finances are in good shape';
    } else if (_financialHealthScore >= 60) {
      _financialHealthMessage = 'Your finances are in fair shape, with room for improvement';
    } else if (_financialHealthScore >= 40) {
      _financialHealthMessage = 'Your finances need attention in several areas';
    } else {
      _financialHealthMessage = 'Your finances need significant improvement';
    }
  }
  
  // Helper method to get color based on score
  Color _getScoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.green.shade400;
    if (score >= 60) return Colors.lightGreen;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  void _filterDataByPeriod() {
    final now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate;
    
    // Determine date range based on selected period
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
      endDate = DateTime(2100); // Far future
    }
    
    // Filter incomes by date
    _filteredIncomes = _incomes.where((income) {
      return income.date.isAfter(startDate!.subtract(const Duration(days: 1))) && 
             income.date.isBefore(endDate!.add(const Duration(days: 1)));
    }).toList();
    
    // Filter expenses by date
    _filteredExpenses = _expenses.where((expense) {
      return expense.date.isAfter(startDate!.subtract(const Duration(days: 1))) && 
             expense.date.isBefore(endDate!.add(const Duration(days: 1)));
    }).toList();
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Dashboard'),
        actions: [
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            tooltip: 'Server Settings',
          ),
          // Period selector
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _showPeriodSelector,
            tooltip: 'Select Period',
          ),
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
              Navigator.of(context).pushNamed('/profile');
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
                  ElevatedButton(
                    onPressed: _loadAllData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome card with financial health score
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back, $_userName',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                CircularPercentIndicator(
                                  radius: 45,
                                  lineWidth: 10,
                                  percent: _financialHealthScore / 100,
                                  center: Text(
                                    _financialHealthScore.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                  progressColor: _getScoreColor(_financialHealthScore),
                                  backgroundColor: Colors.grey.shade200,
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Financial Health Score',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _financialHealthMessage,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Monthly cash flow
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Cash Flow'),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            _getDateRangeText(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Income ($_selectedPeriod)'),
                                Text(
                                  currencyFormatter.format(_totalIncome),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Expenses ($_selectedPeriod)'),
                                Text(
                                  currencyFormatter.format(_totalExpenses),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Net Flow ($_selectedPeriod)',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  currencyFormatter.format(_totalIncome - _totalExpenses),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: _totalIncome - _totalExpenses >= 0 ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Net worth
                    _buildSectionTitle('Net Worth'),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              currencyFormatter.format(_netWorth),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: _netWorth >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Net worth bar
                            LinearPercentIndicator(
                              lineHeight: 18,
                              percent: _totalAssets > 0 ? _totalAssets / (_totalAssets + _totalLiabilities) : 0,
                              backgroundColor: Colors.red.shade100,
                              progressColor: Colors.green.shade500,
                              barRadius: const Radius.circular(10),
                              center: Text(
                                '${(_totalAssets > 0 ? _totalAssets / (_totalAssets + _totalLiabilities) * 100 : 0).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildLegendItem('Assets', Colors.green.shade500, currencyFormatter.format(_totalAssets)),
                                _buildLegendItem('Liabilities', Colors.red.shade100, currencyFormatter.format(_totalLiabilities)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Income & Expense Distribution
                    _buildSectionTitle(_selectedPeriod == 'All Time' ? 'Distribution' : 'Distribution ($_selectedPeriod)'),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          // Income distribution
                          _incomeByCategory.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No income data available'),
                              )
                            : _buildCategoryPieChart('Income by Category', _incomeByCategory, true),
                          
                          const Divider(height: 1),
                          
                          // Expense distribution
                          _expensesByCategory.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No expense data available'),
                              )
                            : _buildCategoryPieChart('Expenses by Category', _expensesByCategory, false),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Goal progress
                    _buildSectionTitle('Financial Goals'),
                    _goals.isEmpty
                      ? _buildEmptyState('No financial goals found', 'Set goals to track your progress', Icons.flag)
                      : Column(
                          children: _goals.take(3).map((goal) => _buildGoalCard(goal)).toList(),
                        ),
                        
                    if (_goals.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/goals');
                          },
                          child: const Text('View All Goals'),
                        ),
                      ),
                      
                    const SizedBox(height: 20),
                    
                    // Quick access buttons
                    _buildSectionTitle('Quick Access'),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildQuickAccessButton(
                                    context,
                                    icon: Icons.attach_money,
                                    label: 'Income',
                                    route: '/income',
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildQuickAccessButton(
                                    context,
                                    icon: Icons.shopping_cart,
                                    label: 'Expenses',
                                    route: '/expenses',
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildQuickAccessButton(
                                    context,
                                    icon: Icons.account_balance,
                                    label: 'Assets',
                                    route: '/assets',
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildQuickAccessButton(
                                    context,
                                    icon: Icons.credit_card,
                                    label: 'Liabilities',
                                    route: '/liabilities',
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showQuickAddMenu(context);
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildLegendItem(String label, Color color, String value) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGoalCard(Goal goal) {
    final progressPercent = goal.targetAmount > 0 
      ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
      : 0.0;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    goal.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: goal.isCompleted ? Colors.green : Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    goal.isCompleted ? 'Completed' : goal.category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currencyFormatter.format(goal.currentAmount),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'of ${currencyFormatter.format(goal.targetAmount)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(progressPercent * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    Text(
                      goal.isOverdue ? 'Overdue' : '${goal.daysRemaining} days left',
                      style: TextStyle(
                        fontSize: 14,
                        color: goal.isOverdue ? Colors.red : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearPercentIndicator(
              lineHeight: 8.0,
              percent: progressPercent,
              progressColor: Theme.of(context).primaryColor,
              backgroundColor: Colors.grey[200],
              barRadius: const Radius.circular(4),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickAccessButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required Color color,
  }) {
    return OutlinedButton(
      onPressed: () {
        Navigator.pushNamed(context, route);
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: color.withOpacity(0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
  
  List<PieChartSectionData> _getPieChartSections(Map<String, double> data, List<Color> colors) {
    final total = data.values.fold(0.0, (sum, value) => sum + value);
    final sections = <PieChartSectionData>[];
    
    int i = 0;
    data.forEach((category, value) {
      final isTouched = i == _touchedIndex;
      final percentage = (value / total) * 100;
      final fontSize = isTouched ? 14.0 : 10.0;
      final radius = isTouched ? 70.0 : 60.0;
      
      sections.add(
        PieChartSectionData(
          color: colors[i % colors.length],
          value: value,
          title: percentage >= 5 ? '${percentage.toStringAsFixed(1)}%' : '',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black,
                blurRadius: 2,
              ),
            ],
          ),
        ),
      );
      i++;
    });
    
    return sections;
  }
  
  Widget _buildCategoryPieChart(String title, Map<String, double> data, bool isIncome) {
    // Generate colors for each category
    final List<Color> categoryColors = _generateCategoryColors(data.keys.toList(), isIncome);
    
    // Sort data by value for the legend
    final sortedData = Map<String, double>.from(data);
    final sortedEntries = sortedData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedMap = Map<String, double>.fromEntries(sortedEntries);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pie chart
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: _getPieChartSections(data, categoryColors),
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (event is FlLongPressEnd || event is FlPanEndEvent) {
                              _touchedIndex = -1;
                            } else {
                              _touchedIndex = pieTouchResponse?.touchedSection?.touchedSectionIndex ?? -1;
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // Legend
              Expanded(
                flex: 2,
                child: _buildCategoryLegend(sortedMap, categoryColors),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  List<Color> _generateCategoryColors(List<String> categories, bool isIncome) {
    final List<Color> baseColors = isIncome 
      ? [
          Colors.blue[400]!,
          Colors.blue[700]!,
          Colors.lightBlue[400]!,
          Colors.cyan[600]!,
          Colors.teal[400]!,
          Colors.green[500]!,
          Colors.lightGreen[600]!,
        ]
      : [
          Colors.red[400]!,
          Colors.deepOrange[400]!,
          Colors.orange[400]!,
          Colors.amber[600]!,
          Colors.pink[400]!,
          Colors.purple[400]!,
          Colors.deepPurple[400]!,
        ];
    
    // Return a color for each category
    final colors = <Color>[];
    for (int i = 0; i < categories.length; i++) {
      colors.add(baseColors[i % baseColors.length]);
    }
    
    return colors;
  }
  
  Widget _buildCategoryLegend(Map<String, double> data, List<Color> colors) {
    final total = data.values.fold(0.0, (sum, value) => sum + value);
    
    return Container(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          data.length,
          (index) {
            final entry = data.entries.elementAt(index);
            final percentage = (entry.value / total) * 100;
            final color = colors[index % colors.length];
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  
  void _showQuickAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add New Item',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Column(
                children: [
                  _buildQuickAddOption(
                    context,
                    icon: Icons.attach_money,
                    title: 'Add Income',
                    route: '/add-income',
                    color: Colors.green,
                  ),
                  _buildQuickAddOption(
                    context,
                    icon: Icons.shopping_cart,
                    title: 'Add Expense',
                    route: '/add-expense',
                    color: Colors.red,
                  ),
                  _buildQuickAddOption(
                    context,
                    icon: Icons.account_balance,
                    title: 'Add Asset',
                    route: '/add-asset',
                    color: Colors.blue,
                  ),
                  _buildQuickAddOption(
                    context,
                    icon: Icons.credit_card,
                    title: 'Add Liability',
                    route: '/add-liability',
                    color: Colors.orange,
                  ),
                  _buildQuickAddOption(
                    context,
                    icon: Icons.flag,
                    title: 'Add Goal',
                    route: '/add-goal',
                    color: Colors.purple,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildQuickAddOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    required Color color,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }

  void _showPeriodSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Select Time Period',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              ...List.generate(
                _filterPeriods.length,
                (index) => ListTile(
                  leading: Icon(
                    _selectedPeriod == _filterPeriods[index]
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: Text(_filterPeriods[index]),
                  subtitle: Text(_getPeriodDescription(_filterPeriods[index])),
                  onTap: () async {
                    final newPeriod = _filterPeriods[index];
                    if (newPeriod != _selectedPeriod) {
                      setState(() {
                        _selectedPeriod = newPeriod;
                      });
                      await _saveSelectedPeriod(newPeriod);
                      _calculateSummaryData();
                    }
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getPeriodDescription(String period) {
    final now = DateTime.now();
    final dateFormat = DateFormat('MMM d, y');
    
    if (period == 'This Month') {
      final startDate = DateTime(now.year, now.month, 1);
      final endDate = DateTime(now.year, now.month + 1, 0);
      return '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}';
    } else if (period == 'Last Month') {
      final startDate = DateTime(now.year, now.month - 1, 1);
      final endDate = DateTime(now.year, now.month, 0);
      return '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}';
    } else if (period == 'This Year') {
      final startDate = DateTime(now.year, 1, 1);
      final endDate = DateTime(now.year, 12, 31);
      return '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}';
    } else {
      return 'All data since the beginning';
    }
  }
} 