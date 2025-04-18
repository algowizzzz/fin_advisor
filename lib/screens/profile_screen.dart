import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../services/api_service.dart';
import '../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isImageUploading = false;
  
  // User data
  User? _user;
  String _userName = 'User';
  String _userEmail = '';
  String? _profileImageBase64;
  
  // Controllers for editing
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _occupationController = TextEditingController();
  DateTime? _dateOfBirth;
  int _age = 30;
  
  // Controllers for password change
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Error messages
  String? _errorMessage;
  String? _passwordErrorMessage;
  String? _successMessage;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _occupationController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Load basic user info from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('userName');
      final userEmail = prefs.getString('userEmail');
      final profileImage = prefs.getString('profileImage');
      final occupation = prefs.getString('occupation');
      final ageString = prefs.getString('age');
      final dobString = prefs.getString('dateOfBirth');
      final phoneNumber = prefs.getString('phoneNumber');
      
      if (mounted) {
        setState(() {
          _userName = userName ?? 'User';
          _userEmail = userEmail ?? '';
          _profileImageBase64 = profileImage;
          _fullNameController.text = userName ?? '';
          _phoneController.text = phoneNumber ?? '';
          _occupationController.text = occupation ?? '';
          _age = ageString != null ? int.tryParse(ageString) ?? 30 : 30;
          _dateOfBirth = dobString != null ? DateTime.tryParse(dobString) : null;
        });
      }
      
      // Try to get user data from API
      final token = await _getToken();
      if (token != null) {
        try {
          final userData = await _apiService.get('users/profile', token: token);
          if (userData != null && userData['data'] != null) {
            final user = User.fromJson(userData['data']);
            
            if (mounted) {
              setState(() {
                _user = user;
                _fullNameController.text = user.fullName;
                _userEmail = user.email;
                _phoneController.text = user.phoneNumber ?? '';
                if (user.dateOfBirth != null) {
                  _dateOfBirth = user.dateOfBirth;
                  _age = DateTime.now().year - user.dateOfBirth!.year;
                }
              });
              
              // Save updated user info to shared preferences
              await prefs.setString('userName', user.fullName);
              await prefs.setString('userEmail', user.email);
              if (user.phoneNumber != null) {
                await prefs.setString('phoneNumber', user.phoneNumber!);
              }
              if (user.dateOfBirth != null) {
                await prefs.setString('dateOfBirth', user.dateOfBirth!.toIso8601String());
                await prefs.setString('age', _age.toString());
              }
            }
          }
        } catch (e) {
          print('Error fetching user profile: $e');
          // Continue with local data if API call fails
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load user data';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      print('Error getting token: $e');
      return null;
    }
  }
  
  Future<void> _saveUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    
    try {
      final token = await _getToken();
      if (token == null) {
        setState(() {
          _errorMessage = 'Authentication token not found. Please log in again.';
          _isLoading = false;
        });
        return;
      }
      
      final userData = {
        'fullName': _fullNameController.text,
        'phoneNumber': _phoneController.text,
        'occupation': _occupationController.text,
      };
      
      if (_dateOfBirth != null) {
        userData['dateOfBirth'] = _dateOfBirth!.toIso8601String();
      }
      
      final response = await _apiService.put('users/profile', userData, token: token);
      
      if (response != null && response['success'] == true) {
        // Update local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userName', _fullNameController.text);
        await prefs.setString('occupation', _occupationController.text);
        await prefs.setString('phoneNumber', _phoneController.text);
        if (_dateOfBirth != null) {
          await prefs.setString('dateOfBirth', _dateOfBirth!.toIso8601String());
          await prefs.setString('age', _age.toString());
        }
        
        setState(() {
          _userName = _fullNameController.text;
          _isEditing = false;
          _successMessage = 'Profile updated successfully';
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to update profile';
        });
      }
    } catch (e) {
      print('Error updating profile: $e');
      setState(() {
        _errorMessage = 'Error updating profile: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _passwordErrorMessage = null;
      _successMessage = null;
    });
    
    try {
      final token = await _getToken();
      if (token == null) {
        setState(() {
          _passwordErrorMessage = 'Authentication token not found. Please log in again.';
          _isLoading = false;
        });
        return;
      }
      
      final passwordData = {
        'currentPassword': _currentPasswordController.text,
        'newPassword': _newPasswordController.text,
      };
      
      final response = await _apiService.put('users/change-password', passwordData, token: token);
      
      if (response != null && response['success'] == true) {
        // Clear password fields
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        
        setState(() {
          _successMessage = 'Password changed successfully';
        });
      } else {
        setState(() {
          _passwordErrorMessage = response?['message'] ?? 'Failed to change password';
        });
      }
    } catch (e) {
      print('Error changing password: $e');
      setState(() {
        _passwordErrorMessage = 'Error changing password: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(DateTime.now().year - _age),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
        _age = DateTime.now().year - picked.year;
      });
    }
  }
  
  Future<void> _pickImage() async {
    setState(() {
      _isImageUploading = true;
      _errorMessage = null;
    });
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 85,
      );
      
      if (image != null) {
        final imageBytes = await image.readAsBytes();
        final base64Image = base64Encode(imageBytes);
        
        // Store the image to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profileImage', base64Image);
        
        // Try to upload to backend if implemented
        final token = await _getToken();
        if (token != null) {
          try {
            await _apiService.put('users/profile-image', {
              'image': base64Image
            }, token: token);
          } catch (e) {
            print('Error uploading profile image to server: $e');
            // Continue with local storage if API call fails
          }
        }
        
        setState(() {
          _profileImageBase64 = base64Image;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      setState(() {
        _errorMessage = 'Failed to upload image: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isImageUploading = false;
      });
    }
  }
  
  Widget _buildProfileImage() {
    if (_isImageUploading) {
      return const CircleAvatar(
        radius: 50,
        child: CircularProgressIndicator(),
      );
    } else if (_profileImageBase64 != null) {
      try {
        return CircleAvatar(
          radius: 50,
          backgroundImage: MemoryImage(base64Decode(_profileImageBase64!)),
        );
      } catch (e) {
        return const CircleAvatar(
          radius: 50,
          backgroundColor: Colors.blue,
          child: Icon(
            Icons.person,
            size: 50,
            color: Colors.white,
          ),
        );
      }
    } else {
      return const CircleAvatar(
        radius: 50,
        backgroundColor: Colors.blue,
        child: Icon(
          Icons.person,
          size: 50,
          color: Colors.white,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _errorMessage = null;
                  _successMessage = null;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  // Reset controllers to original values
                  _loadUserData();
                });
              },
            ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Profile image and name
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            _buildProfileImage(),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor,
                                radius: 18,
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt, size: 18),
                                  color: Colors.white,
                                  onPressed: _pickImage,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _userEmail,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Success or error message
                  if (_successMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: TextStyle(color: Colors.green.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Profile information form
                  _isEditing
                      ? _buildEditForm()
                      : _buildProfileInfo(),
                  
                  const SizedBox(height: 16),
                  
                  // Change Password Section
                  ExpansionTile(
                    title: const Text(
                      'Change Password',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildChangePasswordForm(),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Logout button
                  ElevatedButton.icon(
                    onPressed: () async {
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
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildProfileInfo() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            
            // Information rows
            _buildInfoRow('Full Name', _fullNameController.text),
            _buildInfoRow('Email', _userEmail),
            _buildInfoRow('Phone', _phoneController.text.isNotEmpty ? _phoneController.text : 'Not provided'),
            _buildInfoRow('Occupation', _occupationController.text.isNotEmpty ? _occupationController.text : 'Not provided'),
            _buildInfoRow(
              'Date of Birth', 
              _dateOfBirth != null 
                  ? DateFormat('MMMM d, yyyy').format(_dateOfBirth!) 
                  : 'Not provided'
            ),
            _buildInfoRow('Age', _age.toString()),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit Profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your full name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _occupationController,
            decoration: const InputDecoration(
              labelText: 'Occupation',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.work),
            ),
          ),
          const SizedBox(height: 16),
          
          GestureDetector(
            onTap: () => _selectDate(context),
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
                      _dateOfBirth == null
                          ? 'Date of Birth'
                          : 'Date of Birth: ${DateFormat('MMMM d, yyyy').format(_dateOfBirth!)}',
                      style: TextStyle(
                        color: _dateOfBirth == null ? Colors.grey : Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Center(
            child: ElevatedButton(
              onPressed: _saveUserProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(_isLoading ? 'Saving...' : 'Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChangePasswordForm() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_passwordErrorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _passwordErrorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          
          TextFormField(
            controller: _currentPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Current Password',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your current password';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New Password',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a new password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm New Password',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your new password';
              }
              if (value != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          Center(
            child: ElevatedButton(
              onPressed: _changePassword,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(_isLoading ? 'Changing...' : 'Change Password'),
            ),
          ),
        ],
      ),
    );
  }
} 