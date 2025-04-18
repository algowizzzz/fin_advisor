import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense_model.dart';
import '../services/api_service.dart';
import 'dart:convert';

class ExpenseFormScreen extends StatefulWidget {
  final Expense? expense;
  
  const ExpenseFormScreen({Key? key, this.expense}) : super(key: key);

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Food';
  bool _isRecurring = false;
  String _selectedFrequency = 'Monthly';
  int _durationMonths = 12;
  bool _isLoading = false;
  String? _errorMessage;
  String _userId = '';
  
  final List<String> _categories = [
    'Food', 
    'Rent', 
    'Utilities', 
    'Transportation', 
    'Entertainment', 
    'Shopping', 
    'Health', 
    'Education', 
    'Travel', 
    'Housing',
    'Other'
  ];
  
  final List<String> _frequencies = [
    'Daily', 
    'Weekly', 
    'Bi-weekly', 
    'Monthly', 
    'Quarterly', 
    'Annually'
  ];
  
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _titleController.text = widget.expense!.title;
      _amountController.text = widget.expense!.amount.toString();
      
      // Handle category safely
      if (_categories.contains(widget.expense!.category)) {
        _selectedCategory = widget.expense!.category;
      } else {
        setState(() {
          _categories.add(widget.expense!.category);
          _selectedCategory = widget.expense!.category;
        });
      }
      
      _selectedDate = widget.expense!.date;
      _descriptionController.text = widget.expense!.description ?? '';
      _isRecurring = widget.expense!.isRecurring;
      
      if (_frequencies.contains(widget.expense!.frequency)) {
        _selectedFrequency = widget.expense!.frequency;
      } else {
        setState(() {
          _frequencies.add(widget.expense!.frequency);
          _selectedFrequency = widget.expense!.frequency;
        });
      }
      
      _durationMonths = widget.expense!.durationMonths ?? 12;
    }
    _getUserId();
  }
  
  Future<void> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final token = prefs.getString('token');
    
    if (token == null) {
      // Only navigate to login if we don't have a token
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication required, please login')),
      );
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    
    if (userId != null) {
      setState(() {
        _userId = userId;
      });
      return;
    }
    
    // If we have a token but no userId, try to get it from the profile API
    try {
      final response = await _apiService.get('users/profile', token: token);
      if (response['success']) {
        final realUserId = response['data']['id'];
        await prefs.setString('userId', realUserId);
        setState(() {
          _userId = realUserId;
        });
        print('Retrieved user ID from profile: $_userId');
      } else {
        throw Exception('Failed to fetch user profile');
      }
    } catch (e) {
      print('Error fetching user profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired, please login again'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final token = await _getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication required, please login')),
      );
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Attempt to rediscover backend port before making API calls
      await _apiService.discoverBackendPort();
      
      final expense = Expense(
        id: widget.expense?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        userId: _userId,
        title: _titleController.text,
        amount: double.parse(_amountController.text),
        category: _selectedCategory,
        date: _selectedDate,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        isRecurring: _isRecurring,
        frequency: _selectedFrequency,
        durationMonths: _isRecurring ? _durationMonths : null,
      );
      
      // Use mock mode if userId starts with 'mock' or if we're offline
      final isMockMode = _userId.startsWith('mock') || await _isOffline();
      
      if (isMockMode) {
        // Don't use API in mock mode, just save locally
        await _saveLocalExpense(expense);
        
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.expense == null 
                ? 'Expense added in offline mode!' 
                : 'Expense updated in offline mode!'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pop(true);
        return;
      }
      
      // Real API call if not using mock data
      final Map<String, dynamic> expenseData = expense.toJson();
      
      print('API call: ${widget.expense == null ? "Creating" : "Updating"} expense with ID: ${expense.id}');
      
      // Important: For PUT requests, use the ID from the original expense object
      final response = widget.expense == null
          ? await _apiService.post('expenses', expenseData, token: token)
          : await _apiService.put('expenses/${widget.expense!.id}', expenseData, token: token);
      
      setState(() {
        _isLoading = false;
      });
      
      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.expense == null 
                ? 'Expense added successfully!' 
                : 'Expense updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        throw Exception(response['message'] ?? 'Failed to save expense');
      }
    } catch (e) {
      print('Error saving expense: $e');
      
      // Always create a fresh expense object for local saving
      final localExpense = Expense(
        // For editing, preserve the original ID
        id: widget.expense?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        userId: _userId,
        title: _titleController.text,
        amount: double.parse(_amountController.text),
        category: _selectedCategory,
        date: _selectedDate,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        isRecurring: _isRecurring,
        frequency: _selectedFrequency,
        durationMonths: _isRecurring ? _durationMonths : null,
      );
      
      // Save to local storage when API fails
      await _saveLocalExpense(localExpense);
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Server error - saved offline: ${e.toString().split(':').first}';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server error - ${widget.expense == null ? "added" : "updated"} offline'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<bool> _isOffline() async {
    try {
      final response = await _apiService.get('health-check', token: await _getToken());
      return response['success'] != true;
    } catch (e) {
      return true;
    }
  }
  
  Future<void> _saveLocalExpense(Expense expense) async {
    try {
      // Get the shared preferences instance to store local expense
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing saved expenses or create new list
      List<String> savedExpenses = prefs.getStringList('offline_expenses') ?? [];
      
      // When editing, remove the existing expense with the same ID first
      if (widget.expense != null) {
        print('Removing existing expense with ID: ${expense.id} before adding updated version');
        savedExpenses.removeWhere((item) {
          try {
            final decoded = jsonDecode(item);
            return decoded['id'] == expense.id;
          } catch (e) {
            return false;
          }
        });
      }
      
      // Convert expense to JSON string and add to the list
      savedExpenses.add(jsonEncode(expense.toJson()));
      
      // Save the updated list back to shared preferences
      await prefs.setStringList('offline_expenses', savedExpenses);
      
      print('Expense saved locally: ${expense.title}');
    } catch (e) {
      print('Error saving expense locally: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expense != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Expense' : 'Add Expense'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                        prefixText: '\$ ',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        if (double.parse(value) <= 0) {
                          return 'Amount must be greater than zero';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedCategory = newValue;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('MMM dd, yyyy').format(_selectedDate),
                            ),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Recurring Expense'),
                      value: _isRecurring,
                      onChanged: (value) {
                        setState(() {
                          _isRecurring = value;
                        });
                      },
                    ),
                    if (_isRecurring) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedFrequency,
                        decoration: const InputDecoration(
                          labelText: 'Frequency',
                          border: OutlineInputBorder(),
                        ),
                        items: _frequencies.map((String frequency) {
                          return DropdownMenuItem<String>(
                            value: frequency,
                            child: Text(frequency),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedFrequency = newValue;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Duration: $_durationMonths months'),
                          ),
                          Expanded(
                            child: Slider(
                              value: _durationMonths.toDouble(),
                              min: 1,
                              max: 60,
                              divisions: 59,
                              label: _durationMonths.toString(),
                              onChanged: (double value) {
                                setState(() {
                                  _durationMonths = value.round();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveExpense,
                        child: Text(
                          isEditing ? 'Update Expense' : 'Add Expense',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 