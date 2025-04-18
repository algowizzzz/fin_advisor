import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/liability_model.dart';
import '../services/api_service.dart';
import 'dart:convert';

class LiabilityFormScreen extends StatefulWidget {
  final Liability? liability;
  
  const LiabilityFormScreen({Key? key, this.liability}) : super(key: key);

  @override
  State<LiabilityFormScreen> createState() => _LiabilityFormScreenState();
}

class _LiabilityFormScreenState extends State<LiabilityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _lenderController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _minimumPaymentController = TextEditingController();
  final _remainingPaymentsController = TextEditingController();
  
  DateTime _startDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 365));
  String _selectedType = 'Credit Card';
  bool _isFixed = true;
  bool _isLoading = false;
  String _userId = '';
  String? _errorMessage;
  
  final List<String> _liabilityTypes = [
    'Credit Card',
    'Mortgage',
    'Auto Loan',
    'Student Loan',
    'Personal Loan',
    'Medical Debt',
    'Other'
  ];
  
  final ApiService _apiService = ApiService();
  final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');

  @override
  void initState() {
    super.initState();
    if (widget.liability != null) {
      _nameController.text = widget.liability!.name;
      _amountController.text = widget.liability!.amount.toString();
      _interestRateController.text = widget.liability!.interestRate.toString();
      if (widget.liability!.lender != null) {
        _lenderController.text = widget.liability!.lender!;
      }
      if (widget.liability!.description != null) {
        _descriptionController.text = widget.liability!.description!;
      }
      if (widget.liability!.minimumPayment != null) {
        _minimumPaymentController.text = widget.liability!.minimumPayment.toString();
      }
      if (widget.liability!.remainingPayments != null) {
        _remainingPaymentsController.text = widget.liability!.remainingPayments.toString();
      }
      _selectedType = widget.liability!.type;
      _startDate = widget.liability!.startDate;
      _dueDate = widget.liability!.dueDate;
      _isFixed = widget.liability!.isFixed;
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
      // Use stored userId if available
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
        // Save it for future use
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
      // If we can't get real ID, log user out
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
    _nameController.dispose();
    _amountController.dispose();
    _interestRateController.dispose();
    _lenderController.dispose();
    _descriptionController.dispose();
    _minimumPaymentController.dispose();
    _remainingPaymentsController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        
        // If the due date is before the start date, update it
        if (_dueDate.isBefore(_startDate)) {
          _dueDate = _startDate.add(const Duration(days: 30));
        }
      });
    }
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _saveLiability() async {
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
      final liabilityData = {
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'amount': double.parse(_amountController.text.trim()),
        'interestRate': double.parse(_interestRateController.text.trim()),
        'startDate': _startDate.toIso8601String(),
        'dueDate': _dueDate.toIso8601String(),
        'isFixed': _isFixed,
      };

      if (_lenderController.text.isNotEmpty) {
        liabilityData['lender'] = _lenderController.text.trim();
      }
      if (_descriptionController.text.isNotEmpty) {
        liabilityData['description'] = _descriptionController.text.trim();
      }
      if (_minimumPaymentController.text.isNotEmpty) {
        liabilityData['minimumPayment'] = double.parse(_minimumPaymentController.text.trim());
      }
      if (_remainingPaymentsController.text.isNotEmpty) {
        liabilityData['remainingPayments'] = int.parse(_remainingPaymentsController.text.trim());
      }
      
      final response = widget.liability == null
          ? await _apiService.post('liabilities', liabilityData, token: token)
          : await _apiService.put('liabilities/${widget.liability!.id}', liabilityData, token: token);
      
      setState(() {
        _isLoading = false;
      });
      
      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.liability == null 
                ? 'Liability added successfully!' 
                : 'Liability updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        throw Exception(response['message'] ?? 'Failed to save liability');
      }
    } catch (e) {
      print('Error saving liability: $e');
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error saving liability: ${e.toString().split(':').first}';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().split(':').first}'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.liability != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Liability' : 'Add Liability'),
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
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: _liabilityTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a type';
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    
                    TextFormField(
                      controller: _interestRateController,
                      decoration: const InputDecoration(
                        labelText: 'Interest Rate (%)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.percent),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an interest rate';
                        }
                        final rate = double.tryParse(value);
                        if (rate == null) {
                          return 'Please enter a valid number';
                        }
                        if (rate < 0) {
                          return 'Interest rate cannot be negative';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectStartDate(context),
                            child: AbsorbPointer(
                              child: TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Start Date',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                controller: TextEditingController(
                                  text: DateFormat('MMM d, yyyy').format(_startDate),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDueDate(context),
                            child: AbsorbPointer(
                              child: TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Due Date',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                controller: TextEditingController(
                                  text: DateFormat('MMM d, yyyy').format(_dueDate),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _lenderController,
                      decoration: const InputDecoration(
                        labelText: 'Lender (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    SwitchListTile(
                      title: const Text('Fixed Payment'),
                      subtitle: const Text('Does this liability have a fixed payment amount?'),
                      value: _isFixed,
                      onChanged: (bool value) {
                        setState(() {
                          _isFixed = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _minimumPaymentController,
                      decoration: const InputDecoration(
                        labelText: 'Minimum Payment (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final amount = double.tryParse(value);
                          if (amount == null) {
                            return 'Please enter a valid number';
                          }
                          if (amount < 0) {
                            return 'Payment cannot be negative';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _remainingPaymentsController,
                      decoration: const InputDecoration(
                        labelText: 'Remaining Payments (optional)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final payments = int.tryParse(value);
                          if (payments == null) {
                            return 'Please enter a valid number';
                          }
                          if (payments < 0) {
                            return 'Payments cannot be negative';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveLiability,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Text(
                            isEditing ? 'Update Liability' : 'Add Liability',
                            style: const TextStyle(fontSize: 16),
                          ),
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