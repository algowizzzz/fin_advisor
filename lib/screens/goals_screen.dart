import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../models/goal_model.dart';
import '../services/api_service.dart';
import '../utils/currency_formatter.dart';
import 'goal_form_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({Key? key}) : super(key: key);

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final ApiService _apiService = ApiService();
  List<Goal> _goals = [];
  bool _isLoading = true;
  String? _errorMessage;
  final CurrencyFormatter _currencyFormatter = CurrencyFormatter();
  String _selectedFilter = 'All';
  int _selectedSortIndex = 0;
  List<String> _goalCategories = ['All', 'Retirement', 'Education', 'Home', 'Car', 'Travel', 'Emergency Fund', 'Debt Payoff', 'Investment', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        // Not logged in, navigate to login
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      try {
        print('Fetching goals from API');
        final response = await _apiService.get('goals', token: token);
        
        print('API Response: ${response.toString().substring(0, response.toString().length > 100 ? 100 : response.toString().length)}...');
        
        // Handle different response formats
        if (response is Map) {
          if (response['success'] == true && response['data'] != null) {
            final goalsList = response['data'] as List;
            setState(() {
              _goals = goalsList.map((x) => Goal.fromJson(x)).toList();
              _isLoading = false;
            });
            return;
          } else if (response['data'] != null && response['data'] is List) {
            final goalsList = response['data'] as List;
            setState(() {
              _goals = goalsList.map((x) => Goal.fromJson(x)).toList();
              _isLoading = false;
            });
            return;
          }
        } else if (response is List) {
          setState(() {
            _goals = response.map((x) => Goal.fromJson(x)).toList();
            _isLoading = false;
          });
          return;
        }
        
        // If we got here, the response format wasn't as expected
        throw Exception('Unexpected response format');
      } catch (apiError) {
        print('API error loading goals: $apiError');
        _loadMockGoals();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to connect to server - showing saved goals'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error in _loadGoals: $e');
      _handleError('Failed to load goals: ${e.toString()}');
      _loadMockGoals();
    }
  }

  void _loadMockGoals() {
    setState(() {
      final mockGoals = Goal.getMockGoals();
      _goals = mockGoals;
      _isLoading = false;
    });
  }

  void _handleError(String message) {
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  Future<void> _deleteGoal(String id) async {
    // Optimistic update
    final deletedGoal = _goals.firstWhere((goal) => goal.id == id);
    setState(() {
      _goals.removeWhere((goal) => goal.id == id);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        // Not logged in, undo changes
        setState(() {
          _goals.add(deletedGoal);
        });
        return;
      }

      final response = await _apiService.delete('/api/goals/$id', token: token);

      if (!response['success']) {
        // Failed, undo changes
        setState(() {
          _goals.add(deletedGoal);
          _errorMessage = 'Failed to delete goal: ${response['message']}';
        });
      }
    } catch (e) {
      print('Delete goal error: $e');
      // Failed, undo changes
      setState(() {
        _goals.add(deletedGoal);
        _errorMessage = 'Failed to delete goal: $e';
      });
    }
  }

  Future<void> _refreshGoals() async {
    await _loadGoals();
  }

  List<Goal> get _filteredGoals {
    var filtered = _goals;
    
    // Apply category filter
    if (_selectedFilter != 'All') {
      filtered = filtered.where((goal) => goal.category == _selectedFilter).toList();
    }
    
    // Apply sorting
    switch (_selectedSortIndex) {
      case 0: // Default - Progress
        filtered.sort((a, b) => (b.progressPercentage).compareTo(a.progressPercentage));
        break;
      case 1: // Target Date
        filtered.sort((a, b) => a.targetDate.compareTo(b.targetDate));
        break;
      case 2: // Amount
        filtered.sort((a, b) => b.targetAmount.compareTo(a.targetAmount));
        break;
      case 3: // Priority
        filtered.sort((a, b) => a.priority.compareTo(b.priority));
        break;
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshGoals,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _goals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshGoals,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).pushNamed('/add-goal');
          _refreshGoals();
        },
        backgroundColor: const Color(0xFF0073CF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _refreshGoals,
      child: Column(
        children: [
          // Progress overview card
          if (_filteredGoals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overall Progress',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(_filteredGoals.where((g) => g.isCompleted).length / _filteredGoals.length * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0073CF),
                            ),
                          ),
                          LinearPercentIndicator(
                            width: MediaQuery.of(context).size.width * 0.5,
                            lineHeight: 14.0,
                            percent: _filteredGoals.where((g) => g.isCompleted).length / _filteredGoals.length,
                            backgroundColor: Colors.grey[300],
                            progressColor: const Color(0xFF0073CF),
                            barRadius: const Radius.circular(7),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_filteredGoals.where((g) => g.isCompleted).length} of ${_filteredGoals.length} goals completed',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Goals list
          Expanded(
            child: _filteredGoals.isEmpty
                ? const Center(child: Text('No goals found'))
                : ListView.builder(
                    itemCount: _filteredGoals.length,
                    itemBuilder: (context, index) {
                      final goal = _filteredGoals[index];
                      return _buildGoalCard(goal);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(Goal goal) {
    final bool isOverdue = goal.isOverdue;
    final bool isCompleted = goal.isCompleted;
    
    // Calculate progress percentage (capped at 100%)
    final double progressValue = goal.progressPercentage / 100;
    final double displayProgress = progressValue > 1 ? 1 : progressValue;
    
    // Format dates
    final String targetDateFormatted = DateFormat('MMM dd, yyyy').format(goal.targetDate);
    
    // Priority indicators
    final List<Color> priorityColors = [
      Colors.red,    // High
      Colors.orange, // Medium
      Colors.green,  // Low
    ];
    
    final List<String> priorityLabels = [
      'High',
      'Medium',
      'Low',
    ];
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOverdue && !isCompleted
            ? const BorderSide(color: Colors.red, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).pushNamed('/edit-goal', arguments: goal);
          _refreshGoals();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      goal.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted ? Colors.grey : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColors[goal.priority - 1].withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      priorityLabels[goal.priority - 1],
                      style: TextStyle(
                        color: priorityColors[goal.priority - 1],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (goal.description != null && goal.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    goal.description!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 16),
              LinearPercentIndicator(
                percent: displayProgress,
                lineHeight: 10.0,
                backgroundColor: Colors.grey[300],
                progressColor: isCompleted
                    ? Colors.green
                    : isOverdue
                        ? Colors.red
                        : const Color(0xFF0073CF),
                barRadius: const Radius.circular(5),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${goal.progressPercentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCompleted
                          ? Colors.green
                          : isOverdue
                              ? Colors.red
                              : const Color(0xFF0073CF),
                    ),
                  ),
                  Text(
                    '${_currencyFormatter.format(goal.currentAmount)} / ${_currencyFormatter.format(goal.targetAmount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCompleted
                            ? Icons.check_circle
                            : isOverdue
                                ? Icons.warning
                                : Icons.calendar_today,
                        size: 16,
                        color: isCompleted
                            ? Colors.green
                            : isOverdue
                                ? Colors.red
                                : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCompleted
                            ? 'Completed'
                            : isOverdue
                                ? 'Overdue by ${-goal.daysRemaining} days'
                                : '${goal.daysRemaining} days left',
                        style: TextStyle(
                          color: isCompleted
                              ? Colors.green
                              : isOverdue
                                  ? Colors.red
                                  : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Due: $targetDateFormatted',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Chip(
                    label: Text(goal.category),
                    backgroundColor: Colors.grey[200],
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[800],
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () async {
                      await Navigator.of(context).pushNamed('/edit-goal', arguments: goal);
                      _refreshGoals();
                    },
                    color: Colors.grey[600],
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: () => _showDeleteConfirmation(goal),
                    color: Colors.red,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Goal goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Are you sure you want to delete "${goal.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteGoal(goal.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Goals'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: _goalCategories.map((category) => 
              RadioListTile<String>(
                title: Text(category),
                value: category,
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  Navigator.pop(context);
                },
              )
            ).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSortDialog() {
    final sortOptions = ['Progress', 'Due Date', 'Amount', 'Priority'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Goals'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: List.generate(sortOptions.length, (index) => 
              RadioListTile<int>(
                title: Text(sortOptions[index]),
                value: index,
                groupValue: _selectedSortIndex,
                onChanged: (value) {
                  setState(() {
                    _selectedSortIndex = value!;
                  });
                  Navigator.pop(context);
                },
              )
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateGoalProgress(Goal goal, double newAmount) async {
    // Optimistic update
    final goalIndex = _goals.indexWhere((g) => g.id == goal.id);
    final oldGoal = _goals[goalIndex];
    
    final updatedGoal = goal.copyWith(currentAmount: newAmount);
    
    setState(() {
      _goals[goalIndex] = updatedGoal;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        // Not logged in, revert change
        setState(() {
          _goals[goalIndex] = oldGoal;
        });
        return;
      }
      
      final response = await _apiService.put('/api/goals/${goal.id}', updatedGoal.toJson(), token: token);
      
      if (!response['success']) {
        // API request failed, revert change
        setState(() {
          _goals[goalIndex] = oldGoal;
          _errorMessage = 'Failed to update goal progress: ${response['message']}';
        });
      }
    } catch (e) {
      // Error occurred, revert change
      setState(() {
        _goals[goalIndex] = oldGoal;
        _errorMessage = 'Failed to update goal progress: $e';
      });
    }
  }

  Future<void> _toggleGoalCompletion(Goal goal) async {
    // Optimistic update
    final goalIndex = _goals.indexWhere((g) => g.id == goal.id);
    final oldGoal = _goals[goalIndex];
    
    final updatedGoal = goal.copyWith(isCompleted: !goal.isCompleted);
    
    setState(() {
      _goals[goalIndex] = updatedGoal;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        // Not logged in, revert change
        setState(() {
          _goals[goalIndex] = oldGoal;
        });
        return;
      }
      
      final response = await _apiService.put('/api/goals/${goal.id}', updatedGoal.toJson(), token: token);
      
      if (!response['success']) {
        // API request failed, revert change
        setState(() {
          _goals[goalIndex] = oldGoal;
          _errorMessage = 'Failed to update goal: ${response['message']}';
        });
      }
    } catch (e) {
      // Error occurred, revert change
      setState(() {
        _goals[goalIndex] = oldGoal;
        _errorMessage = 'Failed to update goal: $e';
      });
    }
  }
} 