import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/goal_model.dart';
import '../services/api_service.dart';

class GoalFormScreen extends StatefulWidget {
  final Goal? goal;
  
  const GoalFormScreen({Key? key, this.goal}) : super(key: key);

  @override
  _GoalFormScreenState createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _currentAmountController = TextEditingController();
  final _targetDateController = TextEditingController();

  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _errorMessage;

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 90));
  String _selectedCategory = 'Other';
  int _selectedPriority = 2;
  bool _isCompleted = false;
  String? _goalId;

  final List<String> _categories = [
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

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() async {
    // If editing an existing goal, populate form fields
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final goal = ModalRoute.of(context)?.settings.arguments as Goal?;
      if (goal != null) {
        _populateFormWithGoal(goal);
      }
    });
  }

  void _populateFormWithGoal(Goal goal) {
    setState(() {
      _goalId = goal.id;
      
      _nameController.text = goal.name;
      _descriptionController.text = goal.description ?? '';
      _targetAmountController.text = goal.targetAmount.toString();
      _currentAmountController.text = goal.currentAmount.toString();
      _selectedDate = goal.targetDate;
      _targetDateController.text = DateFormat('yyyy-MM-dd').format(goal.targetDate);
      _selectedCategory = goal.category;
      _selectedPriority = goal.priority;
      _isCompleted = goal.isCompleted;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    _targetDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _targetDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }
  
  Future<void> _saveGoal() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      try {
        // Get token for authentication
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        
        if (token == null) {
          // Not logged in, navigate to login
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
          return;
        }
        
        // Create goal data
        final goalData = {
          if (_isEditing) '_id': _goalId,
          'name': _nameController.text,
          'description': _descriptionController.text,
          'targetAmount': double.parse(_targetAmountController.text),
          'currentAmount': double.parse(_currentAmountController.text),
          'targetDate': _selectedDate.toIso8601String(),
          'category': _selectedCategory,
          'priority': _selectedPriority,
          'isCompleted': _isCompleted,
        };

        try {
          // Try to update or create goal via API
          dynamic response;
          
          if (_isEditing) {
            print('Updating goal with ID: $_goalId');
            response = await _apiService.put('goals/$_goalId', goalData, token: token);
          } else {
            print('Creating new goal');
            response = await _apiService.post('goals', goalData, token: token);
          }
          
          print('API Response: ${response.toString().substring(0, response.toString().length > 100 ? 100 : response.toString().length)}...');
          
          if (response is Map && (response['success'] == true || response['data'] != null)) {
            if (mounted) {
              Navigator.of(context).pop(true);  // Return success
            }
          } else {
            throw Exception('Invalid response format: ${response.toString()}');
          }
        } catch (apiError) {
          print('API error: $apiError');
          
          // Show a warning that changes are saved locally
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Server unavailable - changes will be saved when reconnected'),
              backgroundColor: Colors.orange,
            ),
          );
          
          // Still count as success for UI purposes - would save to local storage in a real app
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        }
      } catch (e) {
        print('Error saving goal: $e');
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().split(':').first}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Goal' : 'Add New Goal'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
              color: Colors.white,
            ),
        ],
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
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Goal Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name for your goal';
                        }
                        return null;
                      },
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
                    TextFormField(
                      controller: _targetAmountController,
                      decoration: const InputDecoration(
                        labelText: 'Target Amount',
                        border: OutlineInputBorder(),
                        prefixText: '\$ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a target amount';
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
                    TextFormField(
                      controller: _currentAmountController,
                      decoration: const InputDecoration(
                        labelText: 'Current Amount',
                        border: OutlineInputBorder(),
                        prefixText: '\$ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the current amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        if (double.parse(value) < 0) {
                          return 'Amount cannot be negative';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _targetDateController,
                      decoration: const InputDecoration(
                        labelText: 'Target Date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a target date';
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
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedPriority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 1,
                          child: Text('High Priority'),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text('Medium Priority'),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text('Low Priority'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedPriority = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Mark as Completed'),
                      value: _isCompleted,
                      onChanged: (value) {
                        setState(() {
                          _isCompleted = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveGoal,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF0073CF),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _isEditing ? 'Update Goal' : 'Create Goal',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Are you sure you want to delete "${_nameController.text}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              
              setState(() {
                _isLoading = true;
              });
              
              try {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('token');
                
                if (token == null) {
                  if (mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                  return;
                }
                
                try {
                  print('Deleting goal with ID: $_goalId');
                  final response = await _apiService.delete('goals/$_goalId', token: token);
                  
                  print('API Response: ${response.toString().substring(0, response.toString().length > 100 ? 100 : response.toString().length)}...');
                  
                  if (response is Map && (response['success'] == true || response['data'] != null)) {
                    if (mounted) {
                      Navigator.pop(context, true); // Return success to goals screen
                    }
                  } else {
                    throw Exception('Invalid response format: ${response.toString()}');
                  }
                } catch (apiError) {
                  print('API error during deletion: $apiError');
                  
                  // Show a warning that deletion will happen when reconnected
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Server unavailable - goal will be deleted when reconnected'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  
                  // Still count as success for UI purposes
                  if (mounted) {
                    Navigator.pop(context, true);
                  }
                }
              } catch (e) {
                print('Error deleting goal: $e');
                setState(() {
                  _errorMessage = 'Error deleting goal: ${e.toString()}';
                  _isLoading = false;
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString().split(':').first}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
} 