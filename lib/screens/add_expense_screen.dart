import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense_model.dart';
import '../services/api_service.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  
  String _category = 'Housing';
  String _frequency = 'monthly';
  bool _isRecurring = true;
  DateTime _selectedDate = DateTime.now();
  int _durationMonths = 12;
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _useMockData = false;
  
  final List<String> _categories = [
    'Housing',
    'Food',
    'Transportation',
    'Utilities',
    'Healthcare',
    'Entertainment',
    'Shopping',
    'Education',
    'Debt',
    'Insurance',
    'Savings',
    'Investments',
    'Other'
  ];
  
  final List<String> _frequencies = [
    'daily', 
    'weekly', 
    'bi-weekly', 
    'monthly', 
    'quarterly', 
    'annually', 
    'one-time'
  ];

  @override
  void initState() {
    super.initState();
    // Initialize date controller with current date
    _dateController.text = DateFormat('MM/dd/yyyy').format(_selectedDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('MM/dd/yyyy').format(_selectedDate);
      });
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      
      // Parse amount from string to double
      final double amount = double.parse(_amountController.text.replaceAll(RegExp(r'[^\d\.]'), ''));
      
      // Create expense object
      final expense = Expense(
        userId: '', // Will be set by server
        title: _titleController.text,
        category: _category,
        amount: amount,
        frequency: _frequency,
        isRecurring: _isRecurring,
        durationMonths: _isRecurring ? _durationMonths : null,
        date: _selectedDate,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
      );
      
      // Save expense to API
      final response = await _apiService.post('expenses', expense.toJson(), token: token);
      
      if (response['success']) {
        setState(() {
          _isLoading = false;
          _useMockData = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pop(true); // Return true to refresh list
      } else {
        throw Exception(response['message'] ?? 'Failed to save expense');
      }
    } catch (e) {
      print('API error: $e');
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save expense: ${e.toString()}';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage ?? 'An error occurred'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title *',
                        hintText: 'e.g. Rent, Groceries',
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
                    
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _category = newValue!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount *',
                        hintText: '0.00',
                        border: OutlineInputBorder(),
                        prefixText: '\$',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        if (double.tryParse(value.replaceAll(RegExp(r'[^\d\.]'), '')) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _dateController,
                      decoration: InputDecoration(
                        labelText: 'Date *',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => _selectDate(context),
                          icon: const Icon(Icons.calendar_today),
                        ),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            title: const Text('Recurring Expense'),
                            value: _isRecurring,
                            onChanged: (bool value) {
                              setState(() {
                                _isRecurring = value;
                                // If not recurring, set to one-time by default
                                if (!value) {
                                  _frequency = 'one-time';
                                } else {
                                  _frequency = 'monthly'; // Default for recurring
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    if (_isRecurring) ...[
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
                        value: _frequency,
                        decoration: const InputDecoration(
                          labelText: 'Frequency *',
                          border: OutlineInputBorder(),
                        ),
                        items: _frequencies
                            .where((f) => f != 'one-time')
                            .map((String frequency) {
                          return DropdownMenuItem<String>(
                            value: frequency,
                            child: Text(frequency),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _frequency = newValue!;
                          });
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        initialValue: _durationMonths.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Duration (months)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (_isRecurring) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a duration';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                          }
                          return null;
                        },
                        onChanged: (value) {
                          if (value.isNotEmpty && int.tryParse(value) != null) {
                            setState(() {
                              _durationMonths = int.parse(value);
                            });
                          }
                        },
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Add notes about this expense',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    ElevatedButton(
                      onPressed: _saveExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0073CF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('SAVE EXPENSE'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 