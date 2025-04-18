class Asset {
  final String? id;
  final String userId;
  final String name;
  final String type;
  final double value;
  final double? purchasePrice;
  final DateTime acquisitionDate;
  final String? location;
  final String? description;
  final bool isAppreciating;
  final double? appreciationRate;

  Asset({
    this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.value,
    this.purchasePrice,
    required this.acquisitionDate,
    this.location,
    this.description,
    required this.isAppreciating,
    this.appreciationRate,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    // Parse date safely
    DateTime parseDate() {
      try {
        if (json['acquisitionDate'] == null) return DateTime.now();
        if (json['acquisitionDate'] is DateTime) return json['acquisitionDate'] as DateTime;
        return DateTime.parse(json['acquisitionDate']);
      } catch (e) {
        print('Error parsing date: $e');
        return DateTime.now();
      }
    }
    
    // Handle user ID safely, could be ObjectId or String
    String parseUserId() {
      final user = json['user'];
      if (user == null) return json['userId'] ?? '';
      if (user is String) return user;
      if (user is Map && user.containsKey('_id')) return user['_id'].toString();
      // Handle if user is an ObjectId
      return user.toString();
    }
    
    return Asset(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      userId: parseUserId(),
      name: json['name'] ?? 'Unnamed Asset',
      type: json['type'] ?? 'Other',
      value: (json['value'] is int) 
          ? (json['value'] as int).toDouble() 
          : (json['value'] ?? 0.0).toDouble(),
      purchasePrice: (json['purchasePrice'] is int) 
          ? (json['purchasePrice'] as int).toDouble() 
          : (json['purchasePrice'] as double?),
      acquisitionDate: parseDate(),
      location: json['location']?.toString(),
      description: json['description']?.toString(),
      isAppreciating: json['isAppreciating'] ?? true,
      appreciationRate: (json['appreciationRate'] is int) 
          ? (json['appreciationRate'] as int).toDouble() 
          : (json['appreciationRate'] as double?),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'name': name,
      'type': type,
      'value': value,
      'acquisitionDate': acquisitionDate.toIso8601String(),
      'isAppreciating': isAppreciating,
    };

    // Don't include the ID if creating a new asset on server
    if (id != null && !id!.startsWith('mock')) data['_id'] = id;
    
    // If userId is present and doesn't look like a mock ID, include it
    if (userId.isNotEmpty && !userId.startsWith('mock') && !userId.startsWith('offline')) {
      data['user'] = userId;
    }
    
    if (purchasePrice != null) data['purchasePrice'] = purchasePrice;
    if (location != null) data['location'] = location;
    if (description != null) data['description'] = description;
    if (appreciationRate != null) data['appreciationRate'] = appreciationRate;

    return data;
  }

  // Create a copy of the asset with some fields changed
  Asset copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    double? value,
    double? purchasePrice,
    DateTime? acquisitionDate,
    String? location,
    String? description,
    bool? isAppreciating,
    double? appreciationRate,
  }) {
    return Asset(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      value: value ?? this.value,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      acquisitionDate: acquisitionDate ?? this.acquisitionDate,
      location: location ?? this.location,
      description: description ?? this.description,
      isAppreciating: isAppreciating ?? this.isAppreciating,
      appreciationRate: appreciationRate ?? this.appreciationRate,
    );
  }
} 