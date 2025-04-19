import 'package:flutter/material.dart';
import '../services/update_api_url.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentUrl = '';
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
  }
  
  Future<void> _loadCurrentUrl() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final url = await ApiUrlUpdater.getCurrentUrl();
      setState(() {
        _currentUrl = url;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading URL: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _setRemoteServer() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await ApiUrlUpdater.setRemoteServer();
      if (success) {
        await _loadCurrentUrl();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connected to remote server')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting remote server: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _setLocalServer() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await ApiUrlUpdater.setLocalServer();
      if (success) {
        await _loadCurrentUrl();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connected to local server')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting local server: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRemoteServer = _currentUrl.contains('44.207.118.69');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Server Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Current connection info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Connection',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                isRemoteServer ? Icons.cloud : Icons.computer,
                                color: isRemoteServer ? Colors.blue : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isRemoteServer ? 'Remote Server (Recommended)' : 'Local Server',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (isRemoteServer)
                                const Chip(
                                  label: Text('ACTIVE'),
                                  backgroundColor: Colors.green,
                                  labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('URL: $_currentUrl'),
                          const SizedBox(height: 16),
                          
                          if (isRemoteServer)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Using remote server for better reliability and to access your data from any device.',
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                          const SizedBox(height: 16),
                          
                          // Server selection
                          const Text(
                            'Server Selection',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: isRemoteServer ? null : _setRemoteServer,
                                icon: const Icon(Icons.cloud),
                                label: const Text('Remote'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isRemoteServer ? Colors.blue.shade300 : null,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              // Local server option - disabled with an explanation tooltip
                              Tooltip(
                                message: 'Local server option is disabled in this version',
                                child: ElevatedButton.icon(
                                  onPressed: null, // Always disabled
                                  icon: const Icon(Icons.computer),
                                  label: const Text('Local'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade300,
                                    foregroundColor: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text(
                    'Server Information',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Remote server info
                  Card(
                    elevation: isRemoteServer ? 3 : 1,
                    color: isRemoteServer ? Colors.blue.shade50 : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.cloud, color: Colors.blue),
                              const SizedBox(width: 8),
                              const Text(
                                'Remote Server',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              if (isRemoteServer)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'IN USE',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text('URL: http://44.207.118.69:5001/api'),
                          const Text('This connects to the deployed server on AWS EC2'),
                          const Text('Benefits: Access your data from anywhere, better reliability'),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Local server info
                  Card(
                    color: Colors.grey.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.computer, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Text(
                                'Local Server (Disabled)',
                                style: TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'URL: http://localhost:5001/api',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          Text(
                            'Local server option is disabled in this version',
                            style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 