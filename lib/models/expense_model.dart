import 'package:intl/intl.dart';

class Expense {
  String? id;
  final String userId;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String? description;
  final bool isRecurring;
  final String frequency;
  final int? durationMonths;

  Expense({
    this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.description,
    required this.isRecurring,
    required this.frequency,
    this.durationMonths,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
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
    String? expenseId;
    if (json['_id'] != null) {
      expenseId = json['_id'];
    } else if (json['id'] != null) {
      expenseId = json['id'];
    }

    return Expense(
      id: expenseId,
      userId: json['user'] ?? json['userId'] ?? 'unknown',
      title: json['title'] ?? 'Untitled Expense',
      amount: json['amount'] is String
          ? double.parse(json['amount'])
          : (json['amount'] ?? 0.0).toDouble(),
      category: json['category'] ?? 'Other',
      date: parsedDate,
      description: json['description'],
      isRecurring: json['isRecurring'] ?? false,
      frequency: json['frequency'] ?? 'One-time',
      durationMonths: json['durationMonths'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'description': description,
      'isRecurring': isRecurring,
      'frequency': frequency,
      'durationMonths': durationMonths,
    };
  }

  String getFormattedAmount() {
    final formatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    return formatter.format(amount);
  }

  String getFormattedDate() {
    return DateFormat('MMMM d, yyyy').format(date);
  }

  // Create a copy of the expense with some fields changed
  Expense copyWith({
    String? id,
    String? userId,
    String? title,
    double? amount,
    String? category,
    DateTime? date,
    String? description,
    bool? isRecurring,
    String? frequency,
    int? durationMonths,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      description: description ?? this.description,
      isRecurring: isRecurring ?? this.isRecurring,
      frequency: frequency ?? this.frequency,
      durationMonths: durationMonths ?? this.durationMonths,
    );
  }
} 