import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/income_model.dart';
import '../models/expense_model.dart';
import '../models/asset_model.dart';
import '../models/liability_model.dart';
import '../models/goal_model.dart';

class OnboardingScreen extends StatefulWidget {
  final String userId;
  final String token;
  
  const OnboardingScreen({
    Key? key, 
    required this.userId, 
    required this.token
  }) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final ApiService _apiService = ApiService();
  final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  
  // Current page index
  int _currentPage = 0;
  
  // Step titles
  final List<String> _stepTitles = [
    'Your Profile',
    'Income Sources',
    'Monthly Expenses',
    'Your Assets',
    'Your Liabilities',
    'Financial Goals'
  ];
  
  // Progress indicators
  bool _isLoading = false;
  String? _errorMessage;
  
  // Form keys for validation
  final _profileFormKey = GlobalKey<FormState>();
  final _incomeFormKey = GlobalKey<FormState>();
  final _expenseFormKey = GlobalKey<FormState>();
  final _assetFormKey = GlobalKey<FormState>();
  final _liabilityFormKey = GlobalKey<FormState>();
  final _goalFormKey = GlobalKey<FormState>();
  
  // User profile data
  String _firstName = '';
  String _lastName = '';
  String _occupation = '';
  int _age = 30;
  
  // Income form controllers and variables
  final _sourceController = TextEditingController();
  final _incomeAmountController = TextEditingController();
  DateTime _incomeDate = DateTime.now();
  String _incomeCategory = 'Employment';
  bool _isRecurring = true;
  String _incomeFrequency = 'monthly';
  
  // Expense form controllers and variables
  final _titleController = TextEditingController();
  final _expenseAmountController = TextEditingController();
  final _expenseDescriptionController = TextEditingController();
  DateTime _expenseDate = DateTime.now();
  String _expenseCategory = 'Housing';
  bool _isExpenseRecurring = true;
  String _expenseFrequency = 'monthly';
  
  // Asset form controllers and variables
  final _assetNameController = TextEditingController();
  final _assetValueController = TextEditingController();
  String _assetType = 'Real Estate';
  
  // Liability form controllers and variables
  final _liabilityNameController = TextEditingController();
  final _liabilityAmountController = TextEditingController();
  final _interestRateController = TextEditingController();
  String _liabilityType = 'Credit Card';
  
  // Goal form controllers and variables
  final _goalNameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _currentAmountController = TextEditingController(text: '0');
  DateTime _targetDate = DateTime.now().add(const Duration(days: 365));
  String _goalCategory = 'Retirement';
  
  // Dropdown category options
  final List<String> _incomeCategories = [
    'Employment', 
    'Investments', 
    'Side Gig', 
    'Rental', 
    'Gifts', 
    'Other'
  ];
  
  final List<String> _expenseCategories = [
    'Housing',
    'Food',
    'Transportation',
    'Utilities',
    'Entertainment',
    'Healthcare',
    'Debt Payments',
    'Personal Care',
    'Education',
    'Shopping',
    'Travel',
    'Savings',
    'Other'
  ];
  
  final List<String> _assetTypes = [
    'Real Estate', 
    'Vehicle', 
    'Investment', 
    'Collectible', 
    'Cryptocurrency',
    'Jewelry',
    'Electronics',
    'Furniture',
    'Other'
  ];
  
  final List<String> _liabilityTypes = [
    'Credit Card',
    'Mortgage',
    'Auto Loan',
    'Student Loan',
    'Personal Loan',
    'Medical Debt',
    'Other'
  ];
  
  final List<String> _goalCategories = [
    'Retirement',
    'Education',
    'Home',
    'Car',
    'Travel',
    'Emergency Fund',
    'Debt Payoff',
    'Investment',
    'Other'
  ];
  
  final List<String> _frequencies = [
    'one-time', 
    'daily', 
    'weekly', 
    'bi-weekly', 
    'monthly', 
    'quarterly', 
    'annually'
  ];

  // Multiple income entries
  final List<Map<String, dynamic>> _incomeEntries = [];
  
  // Multiple expense entries
  final List<Map<String, dynamic>> _expenseEntries = [];
  
  // Multiple asset entries
  final List<Map<String, dynamic>> _assetEntries = [];
  
  // Multiple liability entries
  final List<Map<String, dynamic>> _liabilityEntries = [];
  
  // Multiple goal entries
  final List<Map<String, dynamic>> _goalEntries = [];

  @override
  void initState() {
    super.initState();
    // Initialize with at least one empty income entry
    _addIncomeEntry();
    
    // Initialize with at least one empty expense entry
    _addExpenseEntry();
    
    // Initialize with at least one empty asset entry
    _addAssetEntry();
    
    // Initialize with at least one empty liability entry
    _addLiabilityEntry();
    
    // Initialize with at least one empty goal entry
    _addGoalEntry();
  }

  // Add method to add a new income entry
  void _addIncomeEntry() {
    _incomeEntries.add({
      'sourceController': TextEditingController(),
      'amountController': TextEditingController(),
      'date': DateTime.now(),
      'category': _incomeCategories[0],
      'isRecurring': true,
      'frequency': _frequencies[4], // monthly
    });
    
    setState(() {});
  }
  
  // Add method to remove an income entry
  void _removeIncomeEntry(int index) {
    if (_incomeEntries.length > 1) {
      // Free controllers
      _incomeEntries[index]['sourceController'].dispose();
      _incomeEntries[index]['amountController'].dispose();
      
      _incomeEntries.removeAt(index);
      setState(() {});
    }
  }
  
  // Add method to add a new expense entry
  void _addExpenseEntry() {
    _expenseEntries.add({
      'titleController': TextEditingController(),
      'amountController': TextEditingController(),
      'descriptionController': TextEditingController(),
      'date': DateTime.now(),
      'category': _expenseCategories[0],
      'isRecurring': true,
      'frequency': _frequencies[4], // monthly
    });
    
    setState(() {});
  }
  
  // Add method to remove an expense entry
  void _removeExpenseEntry(int index) {
    if (_expenseEntries.length > 1) {
      // Free controllers
      _expenseEntries[index]['titleController'].dispose();
      _expenseEntries[index]['amountController'].dispose();
      _expenseEntries[index]['descriptionController'].dispose();
      
      _expenseEntries.removeAt(index);
      setState(() {});
    }
  }

  // Add method to add a new asset entry
  void _addAssetEntry() {
    _assetEntries.add({
      'nameController': TextEditingController(),
      'valueController': TextEditingController(),
      'type': _assetTypes[0],
      'acquisitionDate': DateTime.now(),
    });
    
    setState(() {});
  }
  
  // Add method to remove an asset entry
  void _removeAssetEntry(int index) {
    if (_assetEntries.length > 1) {
      // Free controllers
      _assetEntries[index]['nameController'].dispose();
      _assetEntries[index]['valueController'].dispose();
      
      _assetEntries.removeAt(index);
      setState(() {});
    }
  }
  
  // Add method to add a new liability entry
  void _addLiabilityEntry() {
    _liabilityEntries.add({
      'nameController': TextEditingController(),
      'amountController': TextEditingController(),
      'interestRateController': TextEditingController(),
      'type': _liabilityTypes[0],
      'startDate': DateTime.now(),
      'dueDate': DateTime.now().add(const Duration(days: 365)),
    });
    
    setState(() {});
  }
  
  // Add method to remove a liability entry
  void _removeLiabilityEntry(int index) {
    if (_liabilityEntries.length > 1) {
      // Free controllers
      _liabilityEntries[index]['nameController'].dispose();
      _liabilityEntries[index]['amountController'].dispose();
      _liabilityEntries[index]['interestRateController'].dispose();
      
      _liabilityEntries.removeAt(index);
      setState(() {});
    }
  }
  
  // Add method to add a new goal entry
  void _addGoalEntry() {
    _goalEntries.add({
      'nameController': TextEditingController(),
      'targetAmountController': TextEditingController(),
      'currentAmountController': TextEditingController(text: '0'),
      'category': _goalCategories[0],
      'targetDate': DateTime.now().add(const Duration(days: 365)),
    });
    
    setState(() {});
  }
  
  // Add method to remove a goal entry
  void _removeGoalEntry(int index) {
    if (_goalEntries.length > 1) {
      // Free controllers
      _goalEntries[index]['nameController'].dispose();
      _goalEntries[index]['targetAmountController'].dispose();
      _goalEntries[index]['currentAmountController'].dispose();
      
      _goalEntries.removeAt(index);
      setState(() {});
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    
    // Dispose controllers for multiple entries
    for (var entry in _incomeEntries) {
      entry['sourceController'].dispose();
      entry['amountController'].dispose();
    }
    
    for (var entry in _expenseEntries) {
      entry['titleController'].dispose();
      entry['amountController'].dispose();
      entry['descriptionController'].dispose();
    }
    
    for (var entry in _assetEntries) {
      entry['nameController'].dispose();
      entry['valueController'].dispose();
    }
    
    for (var entry in _liabilityEntries) {
      entry['nameController'].dispose();
      entry['amountController'].dispose();
      entry['interestRateController'].dispose();
    }
    
    for (var entry in _goalEntries) {
      entry['nameController'].dispose();
      entry['targetAmountController'].dispose();
      entry['currentAmountController'].dispose();
    }
    
    // Original controllers to dispose
    _sourceController.dispose();
    _incomeAmountController.dispose();
    _titleController.dispose();
    _expenseAmountController.dispose();
    _expenseDescriptionController.dispose();
    _assetNameController.dispose();
    _assetValueController.dispose();
    _liabilityNameController.dispose();
    _liabilityAmountController.dispose();
    _interestRateController.dispose();
    _goalNameController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    super.dispose();
  }

  void _nextPage() {
    // Validate current form before moving to next page
    if (_validateCurrentForm()) {
      if (_currentPage < 5) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _completeOnboarding();
      }
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentForm() {
    switch (_currentPage) {
      case 0:
        return _profileFormKey.currentState?.validate() ?? false;
      case 1:
        return _validateIncomeForm();
      case 2:
        return _validateExpenseForm();
      case 3:
        return _validateAssetForm();
      case 4:
        return _validateLiabilityForm();
      case 5:
        return _validateGoalForm();
      default:
        return true;
    }
  }

  Future<void> _saveProfile() async {
    // Update user profile (optional fields)
    try {
      await _apiService.put(
        'users/profile',
        {
          'firstName': _firstName,
          'lastName': _lastName,
          'occupation': _occupation,
          'age': _age
        },
        token: widget.token
      );
    } catch (e) {
      print('Error updating profile: $e');
    }
  }

  Future<void> _saveIncome() async {
    try {
      // Save all income entries
      for (var incomeEntry in _incomeEntries) {
        final sourceController = incomeEntry['sourceController'] as TextEditingController;
        final amountController = incomeEntry['amountController'] as TextEditingController;
        
        // Skip if required fields are empty
        if (sourceController.text.isEmpty || amountController.text.isEmpty) {
          continue;
        }
        
        final income = {
          'source': sourceController.text,
          'amount': double.parse(amountController.text),
          'frequency': incomeEntry['frequency'],
          'category': incomeEntry['category'],
          'date': incomeEntry['date'].toIso8601String(),
          'isRecurring': incomeEntry['isRecurring'],
        };

        await _apiService.post('incomes', income, token: widget.token);
      }
    } catch (e) {
      print('Error saving income: $e');
    }
  }

  Future<void> _saveExpense() async {
    try {
      // Save all expense entries
      for (var expenseEntry in _expenseEntries) {
        final titleController = expenseEntry['titleController'] as TextEditingController;
        final amountController = expenseEntry['amountController'] as TextEditingController;
        final descriptionController = expenseEntry['descriptionController'] as TextEditingController;
        
        // Skip if required fields are empty
        if (titleController.text.isEmpty || amountController.text.isEmpty) {
          continue;
        }
        
        final expense = {
          'title': titleController.text,
          'amount': double.parse(amountController.text),
          'category': expenseEntry['category'],
          'date': expenseEntry['date'].toIso8601String(),
          'isRecurring': expenseEntry['isRecurring'],
          'frequency': expenseEntry['frequency'],
          'description': descriptionController.text,
        };

        await _apiService.post('expenses', expense, token: widget.token);
      }
    } catch (e) {
      print('Error saving expense: $e');
    }
  }

  Future<void> _saveAsset() async {
    try {
      // Save all asset entries
      for (var assetEntry in _assetEntries) {
        final nameController = assetEntry['nameController'] as TextEditingController;
        final valueController = assetEntry['valueController'] as TextEditingController;
        
        // Skip if required fields are empty
        if (nameController.text.isEmpty || valueController.text.isEmpty) {
          continue;
        }
        
        final asset = {
          'name': nameController.text,
          'type': assetEntry['type'],
          'value': double.parse(valueController.text),
          'acquisitionDate': assetEntry['acquisitionDate'].toIso8601String(),
        };

        await _apiService.post('assets', asset, token: widget.token);
      }
    } catch (e) {
      print('Error saving asset: $e');
    }
  }

  Future<void> _saveLiability() async {
    try {
      // Save all liability entries
      for (var liabilityEntry in _liabilityEntries) {
        final nameController = liabilityEntry['nameController'] as TextEditingController;
        final amountController = liabilityEntry['amountController'] as TextEditingController;
        final interestRateController = liabilityEntry['interestRateController'] as TextEditingController;
        
        // Skip if required fields are empty
        if (nameController.text.isEmpty || amountController.text.isEmpty) {
          continue;
        }
        
        final liability = {
          'name': nameController.text,
          'type': liabilityEntry['type'],
          'amount': double.parse(amountController.text),
          'interestRate': double.tryParse(interestRateController.text) ?? 0.0,
          'startDate': liabilityEntry['startDate'].toIso8601String(),
          'dueDate': liabilityEntry['dueDate'].toIso8601String(),
        };

        await _apiService.post('liabilities', liability, token: widget.token);
      }
    } catch (e) {
      print('Error saving liability: $e');
    }
  }

  Future<void> _saveGoal() async {
    try {
      // Save all goal entries
      for (var goalEntry in _goalEntries) {
        final nameController = goalEntry['nameController'] as TextEditingController;
        final targetAmountController = goalEntry['targetAmountController'] as TextEditingController;
        final currentAmountController = goalEntry['currentAmountController'] as TextEditingController;
        
        // Skip if required fields are empty
        if (nameController.text.isEmpty || targetAmountController.text.isEmpty) {
          continue;
        }
        
        final goal = {
          'name': nameController.text,
          'category': goalEntry['category'],
          'targetAmount': double.parse(targetAmountController.text),
          'currentAmount': double.parse(currentAmountController.text),
          'targetDate': goalEntry['targetDate'].toIso8601String(),
        };

        await _apiService.post('goals', goal, token: widget.token);
      }
    } catch (e) {
      print('Error saving goal: $e');
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Save all data from each form
      await _saveProfile();
      await _saveIncome();
      await _saveExpense();
      await _saveAsset();
      await _saveLiability();
      await _saveGoal();

      // Mark onboarding as complete
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);

      // Navigate to the dashboard
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving data: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectIncomeDate(BuildContext context, int index) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _incomeEntries[index]['date'],
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _incomeEntries[index]['date']) {
      setState(() {
        _incomeEntries[index]['date'] = picked;
      });
    }
  }

  Future<void> _selectExpenseDate(BuildContext context, int index) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expenseEntries[index]['date'],
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _expenseEntries[index]['date']) {
      setState(() {
        _expenseEntries[index]['date'] = picked;
      });
    }
  }

  Future<void> _selectTargetDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _targetDate) {
      setState(() {
        _targetDate = picked;
      });
    }
  }

  void _skipCurrentPage() {
    if (_currentPage < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Onboarding: ${_stepTitles[_currentPage]}'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Progress indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      children: List.generate(
                        _stepTitles.length,
                        (index) => Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: index <= _currentPage
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Error message if any
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  // Page content
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (int page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                      children: [
                        _buildProfileForm(),
                        _buildIncomeForm(),
                        _buildExpenseForm(),
                        _buildAssetForm(),
                        _buildLiabilityForm(),
                        _buildGoalForm(),
                      ],
                    ),
                  ),
                  
                  // Navigation buttons
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentPage > 0)
                          ElevatedButton(
                            onPressed: _previousPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Previous'),
                          )
                        else
                          const SizedBox(width: 85),
                        
                        Text(
                          'Step ${_currentPage + 1} of 6',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        Row(
                          children: [
                            if (_currentPage < 5) // Don't show Skip on last page
                              TextButton(
                                onPressed: _skipCurrentPage,
                                child: const Text('Skip'),
                              ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _nextPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(_currentPage == 5 ? 'Finish' : 'Next'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Information',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tell us a bit about yourself to personalize your financial journey.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            TextFormField(
              initialValue: _occupation,
              decoration: const InputDecoration(
                labelText: 'Occupation',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your occupation';
                }
                return null;
              },
              onChanged: (value) {
                _occupation = value;
              },
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                const Text('Age: ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Slider(
                    value: _age.toDouble(),
                    min: 18,
                    max: 100,
                    divisions: 82,
                    label: _age.toString(),
                    onChanged: (double value) {
                      setState(() {
                        _age = value.round();
                      });
                    },
                  ),
                ),
                Text(
                  _age.toString(),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            Center(
              child: Text(
                "Your financial journey starts with understanding yourself!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _incomeFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Income Sources',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your income sources to get started.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // List of income entries
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _incomeEntries.length,
              itemBuilder: (context, index) {
                final entry = _incomeEntries[index];
                final sourceController = entry['sourceController'] as TextEditingController;
                final amountController = entry['amountController'] as TextEditingController;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Income Source ${index + 1}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_incomeEntries.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _removeIncomeEntry(index),
                                color: Colors.red,
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        TextFormField(
                          controller: sourceController,
                          decoration: const InputDecoration(
                            labelText: 'Source (e.g. Salary, Freelance)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: amountController,
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            border: OutlineInputBorder(),
                            prefixText: '\$',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        
                        DropdownButtonFormField<String>(
                          value: entry['category'],
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: _incomeCategories.map((String category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            if (value != null) {
                              setState(() {
                                entry['category'] = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        GestureDetector(
                          onTap: () => _selectIncomeDate(context, index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.grey),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Date: ${DateFormat('MMM dd, yyyy').format(entry['date'])}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        SwitchListTile(
                          title: const Text('Recurring Income'),
                          value: entry['isRecurring'],
                          onChanged: (bool value) {
                            setState(() {
                              entry['isRecurring'] = value;
                            });
                          },
                        ),
                        
                        if (entry['isRecurring'])
                          DropdownButtonFormField<String>(
                            value: entry['frequency'],
                            decoration: const InputDecoration(
                              labelText: 'Frequency',
                              border: OutlineInputBorder(),
                            ),
                            items: _frequencies.map((String frequency) {
                              return DropdownMenuItem<String>(
                                value: frequency,
                                child: Text(frequency.replaceFirst(frequency[0], frequency[0].toUpperCase())),
                              );
                            }).toList(),
                            onChanged: (String? value) {
                              if (value != null) {
                                setState(() {
                                  entry['frequency'] = value;
                                });
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // Button to add new income entry
            Center(
              child: ElevatedButton.icon(
                onPressed: _addIncomeEntry,
                icon: const Icon(Icons.add),
                label: const Text('Add Another Income Source'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            
            // Add motivational text at the bottom
            const SizedBox(height: 32),
            Center(
              child: Text(
                "Knowing your income is the first step to financial freedom!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _expenseFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Expenses',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your recurring expenses and bills.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // List of expense entries
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _expenseEntries.length,
              itemBuilder: (context, index) {
                final entry = _expenseEntries[index];
                final titleController = entry['titleController'] as TextEditingController;
                final amountController = entry['amountController'] as TextEditingController;
                final descriptionController = entry['descriptionController'] as TextEditingController;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Expense ${index + 1}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_expenseEntries.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _removeExpenseEntry(index),
                                color: Colors.red,
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title (e.g. Rent, Utilities)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: amountController,
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            border: OutlineInputBorder(),
                            prefixText: '\$',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        
                        DropdownButtonFormField<String>(
                          value: entry['category'],
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: _expenseCategories.map((String category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            if (value != null) {
                              setState(() {
                                entry['category'] = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        GestureDetector(
                          onTap: () => _selectExpenseDate(context, index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.grey),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Date: ${DateFormat('MMM dd, yyyy').format(entry['date'])}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        SwitchListTile(
                          title: const Text('Recurring Expense'),
                          value: entry['isRecurring'],
                          onChanged: (bool value) {
                            setState(() {
                              entry['isRecurring'] = value;
                            });
                          },
                        ),
                        
                        if (entry['isRecurring'])
                          DropdownButtonFormField<String>(
                            value: entry['frequency'],
                            decoration: const InputDecoration(
                              labelText: 'Frequency',
                              border: OutlineInputBorder(),
                            ),
                            items: _frequencies.map((String frequency) {
                              return DropdownMenuItem<String>(
                                value: frequency,
                                child: Text(frequency.replaceFirst(frequency[0], frequency[0].toUpperCase())),
                              );
                            }).toList(),
                            onChanged: (String? value) {
                              if (value != null) {
                                setState(() {
                                  entry['frequency'] = value;
                                });
                              }
                            },
                          ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description (Optional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // Button to add new expense entry
            Center(
              child: ElevatedButton.icon(
                onPressed: _addExpenseEntry,
                icon: const Icon(Icons.add),
                label: const Text('Add Another Expense'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            
            // Add motivational text at the bottom
            const SizedBox(height: 32),
            Center(
              child: Text(
                "Being aware of your expenses gives you control over your finances!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _assetFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Assets',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add significant assets you own (home, car, investments).',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // List of asset entries
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _assetEntries.length,
              itemBuilder: (context, index) {
                final entry = _assetEntries[index];
                final nameController = entry['nameController'] as TextEditingController;
                final valueController = entry['valueController'] as TextEditingController;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Asset ${index + 1}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_assetEntries.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _removeAssetEntry(index),
                                color: Colors.red,
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Asset Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: valueController,
                          decoration: const InputDecoration(
                            labelText: 'Current Value',
                            border: OutlineInputBorder(),
                            prefixText: '\$',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        
                        DropdownButtonFormField<String>(
                          value: entry['type'],
                          decoration: const InputDecoration(
                            labelText: 'Asset Type',
                            border: OutlineInputBorder(),
                          ),
                          items: _assetTypes.map((String type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            if (value != null) {
                              setState(() {
                                entry['type'] = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        GestureDetector(
                          onTap: () => _selectAssetAcquisitionDate(context, index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.grey),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Acquisition Date: ${DateFormat('MMM dd, yyyy').format(entry['acquisitionDate'])}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // Button to add new asset entry
            Center(
              child: ElevatedButton.icon(
                onPressed: _addAssetEntry,
                icon: const Icon(Icons.add),
                label: const Text('Add Another Asset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            
            // Add motivational text at the bottom
            const SizedBox(height: 32),
            Center(
              child: Text(
                "Your assets are building blocks to long-term wealth!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiabilityForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _liabilityFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Liabilities',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add any significant debts or loans.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // List of liability entries
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _liabilityEntries.length,
              itemBuilder: (context, index) {
                final entry = _liabilityEntries[index];
                final nameController = entry['nameController'] as TextEditingController;
                final amountController = entry['amountController'] as TextEditingController;
                final interestRateController = entry['interestRateController'] as TextEditingController;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Liability ${index + 1}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_liabilityEntries.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _removeLiabilityEntry(index),
                                color: Colors.red,
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Liability Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: amountController,
                          decoration: const InputDecoration(
                            labelText: 'Outstanding Amount',
                            border: OutlineInputBorder(),
                            prefixText: '\$',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        
                        DropdownButtonFormField<String>(
                          value: entry['type'],
                          decoration: const InputDecoration(
                            labelText: 'Liability Type',
                            border: OutlineInputBorder(),
                          ),
                          items: _liabilityTypes.map((String type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            if (value != null) {
                              setState(() {
                                entry['type'] = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: interestRateController,
                          decoration: const InputDecoration(
                            labelText: 'Interest Rate (%)',
                            border: OutlineInputBorder(),
                            suffixText: '%',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _selectLiabilityStartDate(context, index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Start Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, color: Colors.grey, size: 16),
                                          const SizedBox(width: 8),
                                          Text(
                                            DateFormat('MMM dd, yyyy').format(entry['startDate']),
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _selectLiabilityDueDate(context, index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Due Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, color: Colors.grey, size: 16),
                                          const SizedBox(width: 8),
                                          Text(
                                            DateFormat('MMM dd, yyyy').format(entry['dueDate']),
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // Button to add new liability entry
            Center(
              child: ElevatedButton.icon(
                onPressed: _addLiabilityEntry,
                icon: const Icon(Icons.add),
                label: const Text('Add Another Liability'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            
            // Add motivational text at the bottom
            const SizedBox(height: 32),
            Center(
              child: Text(
                "Facing your liabilities is a brave step toward financial health!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _goalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial Goals',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add financial goals to track your progress.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // List of goal entries
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _goalEntries.length,
              itemBuilder: (context, index) {
                final entry = _goalEntries[index];
                final nameController = entry['nameController'] as TextEditingController;
                final targetAmountController = entry['targetAmountController'] as TextEditingController;
                final currentAmountController = entry['currentAmountController'] as TextEditingController;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Goal ${index + 1}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_goalEntries.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _removeGoalEntry(index),
                                color: Colors.red,
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Goal Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: targetAmountController,
                          decoration: const InputDecoration(
                            labelText: 'Target Amount',
                            border: OutlineInputBorder(),
                            prefixText: '\$',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: currentAmountController,
                          decoration: const InputDecoration(
                            labelText: 'Current Amount (if any)',
                            border: OutlineInputBorder(),
                            prefixText: '\$',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        
                        DropdownButtonFormField<String>(
                          value: entry['category'],
                          decoration: const InputDecoration(
                            labelText: 'Goal Category',
                            border: OutlineInputBorder(),
                          ),
                          items: _goalCategories.map((String category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            if (value != null) {
                              setState(() {
                                entry['category'] = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        GestureDetector(
                          onTap: () => _selectGoalTargetDate(context, index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.grey),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Target Date: ${DateFormat('MMM dd, yyyy').format(entry['targetDate'])}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // Button to add new goal entry
            Center(
              child: ElevatedButton.icon(
                onPressed: _addGoalEntry,
                icon: const Icon(Icons.add),
                label: const Text('Add Another Goal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            
            // Add motivational text at the bottom
            const SizedBox(height: 32),
            Center(
              child: Text(
                "Setting goals is the final piece to your financial puzzle. You're almost there!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _validateIncomeForm() {
    // At least one income entry should be valid
    bool isValid = false;
    
    for (var i = 0; i < _incomeEntries.length; i++) {
      final sourceController = _incomeEntries[i]['sourceController'] as TextEditingController;
      final amountController = _incomeEntries[i]['amountController'] as TextEditingController;
      
      // Check if this entry has both required fields filled
      if (sourceController.text.isNotEmpty && 
          amountController.text.isNotEmpty && 
          double.tryParse(amountController.text) != null) {
        isValid = true;
        break;
      }
    }
    
    return isValid;
  }

  bool _validateExpenseForm() {
    // At least one expense entry should be valid
    bool isValid = false;
    
    for (var i = 0; i < _expenseEntries.length; i++) {
      final titleController = _expenseEntries[i]['titleController'] as TextEditingController;
      final amountController = _expenseEntries[i]['amountController'] as TextEditingController;
      
      // Check if this entry has both required fields filled
      if (titleController.text.isNotEmpty && 
          amountController.text.isNotEmpty && 
          double.tryParse(amountController.text) != null) {
        isValid = true;
        break;
      }
    }
    
    return isValid;
  }

  bool _validateAssetForm() {
    // At least one asset entry should be valid
    bool isValid = false;
    
    for (var i = 0; i < _assetEntries.length; i++) {
      final nameController = _assetEntries[i]['nameController'] as TextEditingController;
      final valueController = _assetEntries[i]['valueController'] as TextEditingController;
      
      // Check if this entry has both required fields filled
      if (nameController.text.isNotEmpty && 
          valueController.text.isNotEmpty && 
          double.tryParse(valueController.text) != null) {
        isValid = true;
        break;
      }
    }
    
    return isValid;
  }

  bool _validateLiabilityForm() {
    // At least one liability entry should be valid
    bool isValid = false;
    
    for (var i = 0; i < _liabilityEntries.length; i++) {
      final nameController = _liabilityEntries[i]['nameController'] as TextEditingController;
      final amountController = _liabilityEntries[i]['amountController'] as TextEditingController;
      
      // Check if this entry has both required fields filled
      if (nameController.text.isNotEmpty && 
          amountController.text.isNotEmpty && 
          double.tryParse(amountController.text) != null) {
        isValid = true;
        break;
      }
    }
    
    return isValid;
  }

  bool _validateGoalForm() {
    // At least one goal entry should be valid
    bool isValid = false;
    
    for (var i = 0; i < _goalEntries.length; i++) {
      final nameController = _goalEntries[i]['nameController'] as TextEditingController;
      final targetAmountController = _goalEntries[i]['targetAmountController'] as TextEditingController;
      
      // Check if this entry has both required fields filled
      if (nameController.text.isNotEmpty && 
          targetAmountController.text.isNotEmpty && 
          double.tryParse(targetAmountController.text) != null) {
        isValid = true;
        break;
      }
    }
    
    return isValid;
  }

  Future<void> _selectAssetAcquisitionDate(BuildContext context, int index) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _assetEntries[index]['acquisitionDate'],
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _assetEntries[index]['acquisitionDate']) {
      setState(() {
        _assetEntries[index]['acquisitionDate'] = picked;
      });
    }
  }

  Future<void> _selectLiabilityStartDate(BuildContext context, int index) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _liabilityEntries[index]['startDate'],
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _liabilityEntries[index]['startDate']) {
      setState(() {
        _liabilityEntries[index]['startDate'] = picked;
      });
    }
  }

  Future<void> _selectLiabilityDueDate(BuildContext context, int index) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _liabilityEntries[index]['dueDate'],
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _liabilityEntries[index]['dueDate']) {
      setState(() {
        _liabilityEntries[index]['dueDate'] = picked;
      });
    }
  }

  Future<void> _selectGoalTargetDate(BuildContext context, int index) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _goalEntries[index]['targetDate'],
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _goalEntries[index]['targetDate']) {
      setState(() {
        _goalEntries[index]['targetDate'] = picked;
      });
    }
  }
} 