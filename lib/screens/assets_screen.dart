import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../models/asset_model.dart';
import '../services/api_service.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({Key? key}) : super(key: key);

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  bool _isLoading = true;
  List<Asset> _assets = [];
  String? _errorMessage;
  bool _useMockData = false;
  final ApiService _apiService = ApiService();
  final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  String _selectedType = 'All';
  List<String> _assetTypes = ['All', 'Real Estate', 'Vehicle', 'Investment', 'Collectible', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get token for authorization
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userId = prefs.getString('userId');
      
      // If no token or userId starts with 'mock', go straight to mock data
      if (token == null || (userId != null && (userId.startsWith('mock') || userId.startsWith('offline')))) {
        await _loadMockAssets();
        return;
      }

      try {
        // Load assets from API
        final response = await _apiService.get('assets', token: token);
        
        print('API response received: ${response.toString().substring(0, min(100, response.toString().length))}...');
        
        // Handle various response formats
        List<dynamic> assetsData;
        if (response is List) {
          // Direct array response
          assetsData = response;
        } else if (response is Map<String, dynamic>) {
          if (response.containsKey('success') && response['success'] == true) {
            // Standard success format
            assetsData = response['data'] ?? [];
          } else if (response.containsKey('data') && response['data'] is List) {
            // Only data field
            assetsData = response['data'];
          } else {
            // Unknown format with data
            throw Exception('Invalid response format: ${response.toString().substring(0, min(100, response.toString().length))}...');
          }
        } else {
          throw Exception('Unknown response type: ${response.runtimeType}');
        }
        
        setState(() {
          _assets = assetsData.map((json) => Asset.fromJson(json)).toList();
          
          // Filter assets if a specific type is selected
          if (_selectedType != 'All') {
            _assets = _assets.where((asset) => asset.type == _selectedType).toList();
          }
          
          // Sort by value descending
          _assets.sort((a, b) => b.value.compareTo(a.value));
          _isLoading = false;
          _useMockData = false;
        });
      } catch (apiError) {
        print('API error: $apiError');
        // If API fails, load mock data
        await _loadMockAssets();
      }
    } catch (e) {
      print('Error loading assets: $e');
      // Even if there's an error getting dates or tokens, load mock data
      await _loadMockAssets();
    }
  }

  Future<void> _loadMockAssets() async {
    try {
      // Get user ID if available for more realistic mock data
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? 'offline-${DateTime.now().millisecondsSinceEpoch}';
      
      setState(() {
        // Mock assets with safe IDs that won't conflict with MongoDB ObjectId
        _assets = [
          Asset(
            id: 'mock-1',
            userId: userId,
            name: 'Primary Residence',
            type: 'Real Estate',
            value: 350000.00,
            purchasePrice: 300000.00,
            acquisitionDate: DateTime.now().subtract(const Duration(days: 1095)),
            location: '123 Main St',
            description: 'Primary home',
            isAppreciating: true,
            appreciationRate: 3.5,
          ),
          Asset(
            id: 'mock-2',
            userId: userId,
            name: 'Car',
            type: 'Vehicle',
            value: 25000.00,
            purchasePrice: 35000.00,
            acquisitionDate: DateTime.now().subtract(const Duration(days: 365)),
            description: 'Toyota Camry',
            isAppreciating: false,
            appreciationRate: -10.0,
          ),
          Asset(
            id: 'mock-3',
            userId: userId,
            name: 'Investment Portfolio',
            type: 'Investment',
            value: 50000.00,
            purchasePrice: 45000.00,
            acquisitionDate: DateTime.now().subtract(const Duration(days: 730)),
            description: 'Stock portfolio',
            isAppreciating: true,
            appreciationRate: 7.0,
          ),
          Asset(
            id: 'mock-4',
            userId: userId,
            name: 'Vacation Property',
            type: 'Real Estate',
            value: 180000.00,
            purchasePrice: 150000.00,
            acquisitionDate: DateTime.now().subtract(const Duration(days: 1825)),
            location: '456 Beach Rd',
            description: 'Beach house',
            isAppreciating: true,
            appreciationRate: 4.2,
          ),
          Asset(
            id: 'mock-5',
            userId: userId,
            name: 'Gold Collection',
            type: 'Collectible',
            value: 15000.00,
            purchasePrice: 12000.00,
            acquisitionDate: DateTime.now().subtract(const Duration(days: 1460)),
            description: 'Gold coins collection',
            isAppreciating: true,
            appreciationRate: 5.0,
          ),
        ];
        
        // Filter assets if a specific type is selected
        if (_selectedType != 'All') {
          _assets = _assets.where((asset) => asset.type == _selectedType).toList();
        }
        
        // Sort by value (descending)
        _assets.sort((a, b) => b.value.compareTo(a.value));
        
        _isLoading = false;
        _useMockData = true;
        _errorMessage = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Using offline data - Server unavailable'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load assets: ${e.toString()}';
        _useMockData = true;
      });
    }
  }

  Future<void> _deleteAsset(String? assetId) async {
    if (assetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete asset with empty ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      // If using mock data or ID starts with 'mock', handle locally without API
      if (_useMockData || assetId.startsWith('mock')) {
        setState(() {
          _assets.removeWhere((asset) => asset.id == assetId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Asset deleted in offline mode'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Get token for authorization
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication required'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      
      // Delete asset via API
      try {
        final response = await _apiService.delete('assets/$assetId', token: token);
        
        if (response['success']) {
          setState(() {
            _assets.removeWhere((asset) => asset.id == assetId);
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Asset deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception(response['message'] ?? 'Failed to delete asset');
        }
      } catch (apiError) {
        print('API error when deleting: $apiError');
        
        // If API fails, still delete locally
        setState(() {
          _assets.removeWhere((asset) => asset.id == assetId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error - asset removed locally'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error deleting asset: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().split(':').first}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshAssets() async {
    setState(() {
      _isLoading = true;
    });
    await _loadAssets();
  }

  String _getAssetTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'real estate':
        return '🏠';
      case 'vehicle':
        return '🚗';
      case 'investment':
        return '📈';
      case 'collectible':
        return '🏆';
      case 'cryptocurrency':
        return '₿';
      case 'jewelry':
        return '💍';
      case 'electronics':
        return '📱';
      case 'furniture':
        return '🪑';
      default:
        return '💰';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assets'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            tooltip: 'Filter by type',
            onSelected: (String newValue) {
              if (newValue != _selectedType) {
                setState(() {
                  _selectedType = newValue;
                });
                _loadAssets();
              }
            },
            itemBuilder: (BuildContext context) {
              return _assetTypes.map((String type) {
                return PopupMenuItem<String>(
                  value: type,
                  child: Row(
                    children: [
                      if (type == _selectedType)
                        const Icon(Icons.check, size: 18, color: Colors.blue),
                      if (type == _selectedType)
                        const SizedBox(width: 8),
                      Text(type),
                    ],
                  ),
                );
              }).toList();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAssets,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                        onPressed: _refreshAssets,
                      ),
                    ],
                  ),
                )
          : _assets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.business, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No assets found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Asset'),
                        onPressed: () async {
                          final result = await Navigator.of(context).pushNamed('/add-asset');
                          if (result == true) {
                            _refreshAssets();
                          }
                        },
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                'Total Assets Value',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currencyFormatter.format(
                                  _assets.fold(0.0, (sum, asset) => sum + asset.value)
                                ),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refreshAssets,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: _assets.length,
                          itemBuilder: (context, index) {
                            final asset = _assets[index];
                            // Calculate profit/loss and percentage change
                            final purchasePrice = asset.purchasePrice ?? 0.0;
                            final profitLoss = asset.value - purchasePrice;
                            final percentChange = purchasePrice > 0 
                                ? (profitLoss / purchasePrice * 100) 
                                : 0.0;
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).primaryColorLight,
                                  child: Text(
                                    _getAssetTypeIcon(asset.type),
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                                title: Text(
                                  asset.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('MMM d, yyyy').format(asset.acquisitionDate),
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    Text(
                                      asset.type,
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    if (asset.location != null)
                                      Text(
                                        asset.location!,
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      currencyFormatter.format(asset.value),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (purchasePrice > 0)
                                      Text(
                                        '${profitLoss >= 0 ? '+' : ''}${currencyFormatter.format(profitLoss)} (${percentChange.toStringAsFixed(1)}%)',
                                        style: TextStyle(
                                          color: profitLoss >= 0 ? Colors.green : Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (ctx) => Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: Theme.of(context).primaryColorLight,
                                                radius: 30,
                                                child: Text(
                                                  _getAssetTypeIcon(asset.type),
                                                  style: const TextStyle(fontSize: 30),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      asset.name,
                                                      style: const TextStyle(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      asset.type,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 24),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Current Value:',
                                                style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                                              ),
                                              Text(
                                                currencyFormatter.format(asset.value),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (asset.purchasePrice != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Purchase Price:',
                                                    style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                                                  ),
                                                  Text(
                                                    currencyFormatter.format(asset.purchasePrice),
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.grey[800],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (purchasePrice > 0)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Profit/Loss:',
                                                    style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                                                  ),
                                                  Text(
                                                    '${profitLoss >= 0 ? '+' : ''}${currencyFormatter.format(profitLoss)} (${percentChange.toStringAsFixed(1)}%)',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: profitLoss >= 0 ? Colors.green : Colors.red,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (asset.appreciationRate != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Annual Rate:',
                                                    style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                                                  ),
                                                  Text(
                                                    '${asset.appreciationRate! >= 0 ? '+' : ''}${asset.appreciationRate!.toStringAsFixed(1)}%',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: asset.appreciationRate! >= 0 ? Colors.green : Colors.red,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today, color: Colors.grey[600]),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Acquired: ${DateFormat('MMMM d, yyyy').format(asset.acquisitionDate)}',
                                                style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                                              ),
                                            ],
                                          ),
                                          if (asset.location != null) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(Icons.location_on, color: Colors.grey[600]),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    asset.location!,
                                                    style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (asset.description != null) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Icon(Icons.description, color: Colors.grey[600]),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    asset.description!,
                                                    style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          const SizedBox(height: 24),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.edit),
                                                label: const Text('Edit'),
                                                onPressed: () async {
                                                  Navigator.of(ctx).pop();
                                                  final result = await Navigator.of(context).pushNamed('/edit-asset', arguments: asset);
                                                  if (result == true) {
                                                    _refreshAssets();
                                                  }
                                                },
                                              ),
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.delete),
                                                label: const Text('Delete'),
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                onPressed: () {
                                                  Navigator.of(ctx).pop();
                                                  showDialog(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: const Text('Delete Asset'),
                                                      content: Text('Are you sure you want to delete "${asset.name}"?'),
                                                      actions: [
                                                        TextButton(
                                                          child: const Text('Cancel'),
                                                          onPressed: () => Navigator.of(ctx).pop(),
                                                        ),
                                                        TextButton(
                                                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                                          onPressed: () {
                                                            Navigator.of(ctx).pop();
                                                            _deleteAsset(asset.id);
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).pushNamed('/add-asset');
          if (result == true) {
            _refreshAssets();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
} 