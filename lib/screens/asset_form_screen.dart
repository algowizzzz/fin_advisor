import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/asset_model.dart';
import '../services/api_service.dart';
import 'dart:convert';

class AssetFormScreen extends StatefulWidget {
  final Asset? asset;
  
  const AssetFormScreen({Key? key, this.asset}) : super(key: key);

  @override
  State<AssetFormScreen> createState() => _AssetFormScreenState();
}

class _AssetFormScreenState extends State<AssetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _appreciationRateController = TextEditingController();
  
  DateTime _acquisitionDate = DateTime.now();
  String _selectedType = 'Real Estate';
  bool _isAppreciating = true;
  bool _isLoading = false;
  String _userId = '';
  String? _errorMessage;
  
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
  
  final ApiService _apiService = ApiService();
  final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');

  @override
  void initState() {
    super.initState();
    if (widget.asset != null) {
      _nameController.text = widget.asset!.name;
      _valueController.text = widget.asset!.value.toString();
      if (widget.asset!.purchasePrice != null) {
        _purchasePriceController.text = widget.asset!.purchasePrice.toString();
      }
      if (widget.asset!.location != null) {
        _locationController.text = widget.asset!.location!;
      }
      if (widget.asset!.description != null) {
        _descriptionController.text = widget.asset!.description!;
      }
      if (widget.asset!.appreciationRate != null) {
        _appreciationRateController.text = widget.asset!.appreciationRate.toString();
      }
      _selectedType = widget.asset!.type;
      _acquisitionDate = widget.asset!.acquisitionDate;
      _isAppreciating = widget.asset!.isAppreciating;
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
    _valueController.dispose();
    _purchasePriceController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _appreciationRateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _acquisitionDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _acquisitionDate) {
      setState(() {
        _acquisitionDate = picked;
      });
    }
  }

  Future<void> _saveAsset() async {
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
      final assetData = {
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'value': double.parse(_valueController.text.trim()),
        'acquisitionDate': _acquisitionDate.toIso8601String(),
        'isAppreciating': _isAppreciating,
      };

      if (_purchasePriceController.text.isNotEmpty) {
        assetData['purchasePrice'] = double.parse(_purchasePriceController.text.trim());
      }
      if (_locationController.text.isNotEmpty) {
        assetData['location'] = _locationController.text.trim();
      }
      if (_descriptionController.text.isNotEmpty) {
        assetData['description'] = _descriptionController.text.trim();
      }
      if (_appreciationRateController.text.isNotEmpty) {
        assetData['appreciationRate'] = double.parse(_appreciationRateController.text.trim());
      }
      
      final response = widget.asset == null
          ? await _apiService.post('assets', assetData, token: token)
          : await _apiService.put('assets/${widget.asset!.id}', assetData, token: token);
      
      setState(() {
        _isLoading = false;
      });
      
      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.asset == null 
                ? 'Asset added successfully!' 
                : 'Asset updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        throw Exception(response['message'] ?? 'Failed to save asset');
      }
    } catch (e) {
      print('Error saving asset: $e');
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error saving asset: ${e.toString().split(':').first}';
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
    final isEditing = widget.asset != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Asset' : 'Add Asset'),
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
                        labelText: 'Asset Name*',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an asset name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Asset Type*',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedType,
                      items: _assetTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedType = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _valueController,
                      decoration: const InputDecoration(
                        labelText: 'Current Value*',
                        border: OutlineInputBorder(),
                        prefixText: '\$',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the current value';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _purchasePriceController,
                      decoration: const InputDecoration(
                        labelText: 'Purchase Price',
                        border: OutlineInputBorder(),
                        prefixText: '\$',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Acquisition Date*',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('MMMM d, yyyy').format(_acquisitionDate)),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Is this asset appreciating in value?'),
                      value: _isAppreciating,
                      onChanged: (bool value) {
                        setState(() {
                          _isAppreciating = value;
                        });
                      },
                    ),
                    if (_isAppreciating) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _appreciationRateController,
                        decoration: const InputDecoration(
                          labelText: 'Annual Appreciation/Depreciation Rate (%)',
                          border: OutlineInputBorder(),
                          hintText: 'e.g. 3.5 for appreciation, -10 for depreciation',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveAsset,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : Text(
                                isEditing ? 'Update Asset' : 'Add Asset',
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