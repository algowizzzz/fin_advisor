class Liability {
  final String? id;
  final String userId;
  final String name;
  final String type;
  final double amount;
  final double interestRate;
  final DateTime startDate;
  final DateTime dueDate;
  final String? lender;
  final String? description;
  final bool isFixed;
  final double? minimumPayment;
  final int? remainingPayments;

  Liability({
    this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.amount,
    required this.interestRate,
    required this.startDate,
    required this.dueDate,
    this.lender,
    this.description,
    required this.isFixed,
    this.minimumPayment,
    this.remainingPayments,
  });

  factory Liability.fromJson(Map<String, dynamic> json) {
    // Parse dates safely
    DateTime parseStartDate() {
      try {
        if (json['startDate'] == null) return DateTime.now();
        if (json['startDate'] is DateTime) return json['startDate'] as DateTime;
        return DateTime.parse(json['startDate']);
      } catch (e) {
        print('Error parsing start date: $e');
        return DateTime.now();
      }
    }
    
    DateTime parseDueDate() {
      try {
        if (json['dueDate'] == null) return DateTime.now().add(const Duration(days: 30));
        if (json['dueDate'] is DateTime) return json['dueDate'] as DateTime;
        return DateTime.parse(json['dueDate']);
      } catch (e) {
        print('Error parsing due date: $e');
        return DateTime.now().add(const Duration(days: 30));
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
    
    return Liability(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      userId: parseUserId(),
      name: json['name'] ?? 'Unnamed Liability',
      type: json['type'] ?? 'Other',
      amount: (json['amount'] is int) 
          ? (json['amount'] as int).toDouble() 
          : (json['amount'] ?? 0.0).toDouble(),
      interestRate: (json['interestRate'] is int) 
          ? (json['interestRate'] as int).toDouble() 
          : (json['interestRate'] ?? 0.0).toDouble(),
      startDate: parseStartDate(),
      dueDate: parseDueDate(),
      lender: json['lender']?.toString(),
      description: json['description']?.toString(),
      isFixed: json['isFixed'] ?? true,
      minimumPayment: (json['minimumPayment'] is int) 
          ? (json['minimumPayment'] as int).toDouble() 
          : (json['minimumPayment'] as double?),
      remainingPayments: json['remainingPayments'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'name': name,
      'type': type,
      'amount': amount,
      'interestRate': interestRate,
      'startDate': startDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'isFixed': isFixed,
    };

    // Don't include the ID if creating a new liability on server
    if (id != null && !id!.startsWith('mock')) data['_id'] = id;
    
    // If userId is present and doesn't look like a mock ID, include it
    if (userId.isNotEmpty && !userId.startsWith('mock') && !userId.startsWith('offline')) {
      data['user'] = userId;
    }
    
    if (lender != null) data['lender'] = lender;
    if (description != null) data['description'] = description;
    if (minimumPayment != null) data['minimumPayment'] = minimumPayment;
    if (remainingPayments != null) data['remainingPayments'] = remainingPayments;

    return data;
  }

  // Create a copy of the liability with some fields changed
  Liability copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    double? amount,
    double? interestRate,
    DateTime? startDate,
    DateTime? dueDate,
    String? lender,
    String? description,
    bool? isFixed,
    double? minimumPayment,
    int? remainingPayments,
  }) {
    return Liability(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      interestRate: interestRate ?? this.interestRate,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      lender: lender ?? this.lender,
      description: description ?? this.description,
      isFixed: isFixed ?? this.isFixed,
      minimumPayment: minimumPayment ?? this.minimumPayment,
      remainingPayments: remainingPayments ?? this.remainingPayments,
    );
  }
} 