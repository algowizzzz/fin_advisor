import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/income_model.dart';
import '../services/api_service.dart';
import 'dart:convert';

class IncomeFormScreen extends StatefulWidget {
  final Income? income;
  
  const IncomeFormScreen({Key? key, this.income}) : super(key: key);

  @override
  State<IncomeFormScreen> createState() => _IncomeFormScreenState();
}

class _IncomeFormScreenState extends State<IncomeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sourceController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Employment';
  bool _isRecurring = true;
  String _selectedFrequency = 'monthly';
  bool _isLoading = false;
  String? _errorMessage;
  String _userId = '';
  
  final List<String> _categories = [
    'Employment', 
    'Investments', 
    'Side Gig', 
    'Rental', 
    'Gifts', 
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
  
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    if (widget.income != null) {
      _sourceController.text = widget.income!.source;
      _amountController.text = widget.income!.amount.toString();
      
      // Handle category safely
      if (_categories.contains(widget.income!.category)) {
        _selectedCategory = widget.income!.category;
      } else {
        setState(() {
          _categories.add(widget.income!.category);
          _selectedCategory = widget.income!.category;
        });
      }
      
      _selectedDate = widget.income!.date;
      _descriptionController.text = widget.income!.description ?? '';
      _isRecurring = widget.income!.isRecurring;
      
      if (_frequencies.contains(widget.income!.frequency)) {
        _selectedFrequency = widget.income!.frequency;
      } else {
        setState(() {
          _frequencies.add(widget.income!.frequency);
          _selectedFrequency = widget.income!.frequency;
        });
      }
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
    _sourceController.dispose();
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

  Future<void> _saveIncome() async {
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
      
      final income = Income(
        id: widget.income?.id,
        userId: _userId,
        source: _sourceController.text,
        amount: double.parse(_amountController.text),
        category: _selectedCategory,
        date: _selectedDate,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        isRecurring: _isRecurring,
        frequency: _selectedFrequency,
      );
      
      Map<String, dynamic> response;
      
      if (widget.income != null) {
        // Update existing income
        response = await _apiService.put('incomes/${income.id}', income.toJson(), token: token);
      } else {
        // Create new income
        response = await _apiService.post('incomes', income.toJson(), token: token);
      }
      
      // Log the response for debugging
      print('API Response: ${response.toString().substring(0, response.toString().length > 100 ? 100 : response.toString().length)}...');
      
      // Check for success in different ways to handle various response formats
      bool success = false;
      
      if (response.containsKey('success')) {
        success = response['success'] == true;
      } else if (response.containsKey('_id') || response.containsKey('id')) {
        // If the response has an ID, it's probably successful
        success = true;
      }
      
      if (!success && response.containsKey('message')) {
        throw Exception(response['message']);
      }
      
      // Also save locally
      _saveLocalIncome(income);
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.income != null ? 'Income updated successfully' : 'Income added successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.of(context).pop();
    } catch (e) {
      print('Error saving income: $e');
      
      // Try to save locally as fallback
      if (widget.income != null) {
        final updatedIncome = Income(
          id: widget.income!.id,
          userId: _userId,
          source: _sourceController.text,
          amount: double.parse(_amountController.text),
          category: _selectedCategory,
          date: _selectedDate,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          isRecurring: _isRecurring,
          frequency: _selectedFrequency,
        );
        
        _saveLocalIncome(updatedIncome);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Server unavailable - income saved locally'),
            backgroundColor: Colors.orange,
          ),
        );
        
        Navigator.of(context).pop();
      } else {
        // New income with generated ID
        final newIncome = Income(
          id: 'local-${DateTime.now().millisecondsSinceEpoch}',
          userId: _userId,
          source: _sourceController.text,
          amount: double.parse(_amountController.text),
          category: _selectedCategory,
          date: _selectedDate,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          isRecurring: _isRecurring,
          frequency: _selectedFrequency,
        );
        
        _saveLocalIncome(newIncome);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Server unavailable - income saved locally'),
            backgroundColor: Colors.orange,
          ),
        );
        
        Navigator.of(context).pop();
      }
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }
  
  Future<void> _saveLocalIncome(Income income) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> localIncomes = prefs.getStringList('offline_incomes') ?? [];
      
      // If editing, remove the old version
      if (income.id != null) {
        localIncomes = localIncomes.where((incomeJson) {
          try {
            final Map<String, dynamic> existingIncome = jsonDecode(incomeJson);
            final id = existingIncome['id'] ?? existingIncome['_id'];
            return id != income.id;
          } catch (e) {
            return true; // Keep entries that can't be parsed
          }
        }).toList();
      }
      
      // Add the new/updated income to local storage
      localIncomes.add(jsonEncode(income.toJson()));
      await prefs.setStringList('offline_incomes', localIncomes);
      
      print('Income saved locally: ${income.source}');
    } catch (e) {
      print('Error saving income locally: $e');
    }
  }
  
  Future<void> _deleteIncome() async {
    if (widget.income == null || widget.income!.id == null) {
      return;
    }
    
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
            onPressed: () async {
              Navigator.of(ctx).pop();
              
              setState(() {
                _isLoading = true;
              });
              
              try {
                final token = await _getToken();
                if (token == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Authentication required, please login')),
                  );
                  Navigator.of(context).pushReplacementNamed('/login');
                  return;
                }
                
                await _apiService.delete('incomes/${widget.income!.id}', token: token);
                
                // Also delete locally
                _deleteLocalIncome(widget.income!.id!);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Income deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
                
                Navigator.of(context).pop(); // Go back to incomes screen
              } catch (e) {
                print('Error deleting income: $e');
                
                // Delete locally as fallback
                if (widget.income?.id != null) {
                  _deleteLocalIncome(widget.income!.id!);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Server unavailable - income deleted locally'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  
                  Navigator.of(context).pop(); // Go back to incomes screen
                } else {
                  setState(() {
                    _isLoading = false;
                    _errorMessage = 'Error deleting income: ${e.toString()}';
                  });
                }
              }
            },
          ),
        ],
      ),
    );
  }
  
  Future<void> _deleteLocalIncome(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> localIncomes = prefs.getStringList('offline_incomes') ?? [];
      
      localIncomes = localIncomes.where((incomeJson) {
        try {
          final Map<String, dynamic> income = jsonDecode(incomeJson);
          final incomeId = income['id'] ?? income['_id'];
          return incomeId != id;
        } catch (e) {
          return true; // Keep entries that can't be parsed
        }
      }).toList();
      
      await prefs.setStringList('offline_incomes', localIncomes);
    } catch (e) {
      print('Error deleting income locally: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.income != null ? 'Edit Income' : 'Add Income'),
        actions: [
          if (widget.income != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteIncome,
            ),
        ],
      ),
      body: _isLoading ? 
        const Center(child: CircularProgressIndicator()) :
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    controller: _sourceController,
                    decoration: const InputDecoration(
                      labelText: 'Source',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an income source';
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
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an amount';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
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
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  GestureDetector(
                    onTap: _pickDate,
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        controller: TextEditingController(
                          text: DateFormat('MMM d, yyyy').format(_selectedDate),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  SwitchListTile(
                    title: const Text('Recurring Income'),
                    value: _isRecurring,
                    onChanged: (value) {
                      setState(() {
                        _isRecurring = value;
                        if (!_isRecurring) {
                          _selectedFrequency = 'one-time';
                        } else if (_selectedFrequency == 'one-time') {
                          _selectedFrequency = 'monthly';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  if (_isRecurring)
                    DropdownButtonFormField<String>(
                      value: _selectedFrequency,
                      decoration: const InputDecoration(
                        labelText: 'Frequency',
                        border: OutlineInputBorder(),
                      ),
                      items: _frequencies.map((frequency) {
                        return DropdownMenuItem(
                          value: frequency,
                          child: Text(frequency.substring(0, 1).toUpperCase() + frequency.substring(1)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFrequency = value!;
                        });
                      },
                    ),
                  
                  if (_isRecurring)
                    const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  
                  ElevatedButton(
                    onPressed: _saveIncome,
                    child: Text(widget.income != null ? 'Update Income' : 'Add Income'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }
} 