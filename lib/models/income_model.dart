import 'package:intl/intl.dart';

class Income {
  String? id;
  final String userId;
  final String source;
  final double amount;
  final String category;
  final DateTime date;
  final String? description;
  final bool isRecurring;
  final String frequency;

  Income({
    this.id,
    required this.userId,
    required this.source,
    required this.amount,
    required this.category,
    required this.date,
    this.description,
    required this.isRecurring,
    required this.frequency,
  });

  factory Income.fromJson(Map<String, dynamic> json) {
    // Handle different date formats
    DateTime parsedDate;
    try {
      if (json['date'] is String) {
        parsedDate = DateTime.parse(json['date']);
      } else if (json['date'] is Map && json['date']['\$date'] != null) {
        parsedDate = DateTime.parse(json['date']['\$date']);
      } else {
        parsedDate = DateTime.now();
      }
    } catch (e) {
      print('Error parsing date: $e');
      parsedDate = DateTime.now();
    }

    // Handle MongoDB ObjectId format
    String? incomeId;
    if (json['_id'] != null) {
      incomeId = json['_id'];
    } else if (json['id'] != null) {
      incomeId = json['id'];
    }

    return Income(
      id: incomeId,
      userId: json['user'] ?? json['userId'] ?? 'unknown',
      source: json['source'] ?? 'Untitled Income',
      amount: json['amount'] is String
          ? double.parse(json['amount'])
          : (json['amount'] ?? 0.0).toDouble(),
      category: json['category'] ?? 'Other',
      date: parsedDate,
      description: json['description'],
      isRecurring: json['isRecurring'] ?? false,
      frequency: json['frequency'] ?? 'one-time',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'source': source,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'description': description,
      'isRecurring': isRecurring,
      'frequency': frequency,
    };
  }

  String getFormattedAmount() {
    final formatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    return formatter.format(amount);
  }

  String getFormattedDate() {
    return DateFormat('MMMM d, yyyy').format(date);
  }

  // Create a copy of the income with some fields changed
  Income copyWith({
    String? id,
    String? userId,
    String? source,
    double? amount,
    String? category,
    DateTime? date,
    String? description,
    bool? isRecurring,
    String? frequency,
  }) {
    return Income(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      source: source ?? this.source,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      description: description ?? this.description,
      isRecurring: isRecurring ?? this.isRecurring,
      frequency: frequency ?? this.frequency,
    );
  }
} 