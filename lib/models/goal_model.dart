class Goal {
  final String id;
  final String user;
  final String name;
  final String? description;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final DateTime startDate;
  final String category;
  final int priority;
  final bool isCompleted;
  final List<Contribution>? contributions;
  final DateTime createdAt;
  final DateTime updatedAt;

  Goal({
    required this.id,
    required this.user,
    required this.name,
    this.description,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.startDate,
    required this.category,
    required this.priority,
    required this.isCompleted,
    this.contributions,
    required this.createdAt,
    required this.updatedAt,
  });

  // Computed properties
  double get progressPercentage {
    return targetAmount > 0 ? (currentAmount / targetAmount) * 100 : 0;
  }

  int get daysRemaining {
    final now = DateTime.now();
    final diff = targetDate.difference(now).inDays;
    return diff;
  }

  // Check if the goal is overdue
  bool get isOverdue {
    return !isCompleted && daysRemaining < 0;
  }

  // Factory constructor to create a Goal from a JSON object
  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['_id'],
      user: json['user'],
      name: json['name'],
      description: json['description'],
      targetAmount: json['targetAmount'].toDouble(),
      currentAmount: json['currentAmount'].toDouble(),
      targetDate: DateTime.parse(json['targetDate']),
      startDate: DateTime.parse(json['startDate']),
      category: json['category'],
      priority: json['priority'],
      isCompleted: json['isCompleted'],
      contributions: json['contributions'] != null
          ? (json['contributions'] as List)
              .map((c) => Contribution.fromJson(c))
              .toList()
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  // Convert Goal to a JSON object
  Map<String, dynamic> toJson() {
    return {
      if (id != 'new') '_id': id,
      'name': name,
      'description': description,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'targetDate': targetDate.toIso8601String(),
      'startDate': startDate.toIso8601String(),
      'category': category,
      'priority': priority,
      'isCompleted': isCompleted,
      'contributions': contributions?.map((c) => c.toJson()).toList(),
    };
  }

  // Create a copy of the Goal with updated fields
  Goal copyWith({
    String? id,
    String? user,
    String? name,
    String? description,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    DateTime? startDate,
    String? category,
    int? priority,
    bool? isCompleted,
    List<Contribution>? contributions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Goal(
      id: id ?? this.id,
      user: user ?? this.user,
      name: name ?? this.name,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      startDate: startDate ?? this.startDate,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      contributions: contributions ?? this.contributions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Create mock goals for testing
  static List<Goal> getMockGoals() {
    final now = DateTime.now();
    return [
      Goal(
        id: 'goal-1',
        user: 'user-1',
        name: 'Emergency Fund',
        description: 'Save 3 months of expenses for emergencies',
        targetAmount: 10000,
        currentAmount: 5000,
        targetDate: now.add(const Duration(days: 90)),
        startDate: now.subtract(const Duration(days: 30)),
        category: 'Emergency Fund',
        priority: 1,
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      ),
      Goal(
        id: 'goal-2',
        user: 'user-1',
        name: 'Down Payment for House',
        description: 'Save for 20% down payment on a house',
        targetAmount: 50000,
        currentAmount: 15000,
        targetDate: now.add(const Duration(days: 730)),
        startDate: now.subtract(const Duration(days: 180)),
        category: 'Home',
        priority: 2,
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      ),
      Goal(
        id: 'goal-3',
        user: 'user-1',
        name: 'New Car',
        description: 'Save for a new car',
        targetAmount: 20000,
        currentAmount: 20000,
        targetDate: now.subtract(const Duration(days: 10)),
        startDate: now.subtract(const Duration(days: 365)),
        category: 'Car',
        priority: 3,
        isCompleted: true,
        createdAt: now,
        updatedAt: now,
      ),
      Goal(
        id: 'goal-4',
        user: 'user-1',
        name: 'Vacation to Europe',
        description: 'Save for a two-week vacation to Europe',
        targetAmount: 8000,
        currentAmount: 2000,
        targetDate: now.add(const Duration(days: 150)),
        startDate: now.subtract(const Duration(days: 90)),
        category: 'Travel',
        priority: 2,
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      ),
      Goal(
        id: 'goal-5',
        user: 'user-1',
        name: 'Pay off Student Loans',
        description: 'Pay off remaining student loans',
        targetAmount: 15000,
        currentAmount: 5000,
        targetDate: now.add(const Duration(days: 365)),
        startDate: now.subtract(const Duration(days: 180)),
        category: 'Debt Payoff',
        priority: 1,
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}

class Contribution {
  final double amount;
  final DateTime date;
  final String? note;

  Contribution({
    required this.amount,
    required this.date,
    this.note,
  });

  factory Contribution.fromJson(Map<String, dynamic> json) {
    return Contribution(
      amount: json['amount'].toDouble(),
      date: DateTime.parse(json['date']),
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }
} 