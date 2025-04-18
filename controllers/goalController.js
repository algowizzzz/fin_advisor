const Goal = require('../models/Goal');

// Get all goals
const getGoals = async (req, res) => {
  try {
    const goals = await Goal.find({ user: req.user.id });
    res.json({ success: true, data: goals });
  } catch (error) {
    console.error("Get goals error:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// Get a single goal by ID
const getGoalById = async (req, res) => {
  try {
    const goal = await Goal.findOne({
      _id: req.params.id,
      user: req.user.id
    });

    if (!goal) {
      return res.status(404).json({ success: false, message: "Goal not found" });
    }

    res.json({ success: true, data: goal });
  } catch (error) {
    console.error("Get goal by ID error:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// Create a new goal
const createGoal = async (req, res) => {
  try {
    const {
      name,
      description,
      targetAmount,
      currentAmount,
      targetDate,
      category,
      priority,
      isCompleted,
      contributions
    } = req.body;

    // Create the goal with user ID from auth middleware
    const newGoal = new Goal({
      user: req.user.id,
      name,
      description,
      targetAmount,
      currentAmount,
      targetDate,
      category,
      priority,
      isCompleted,
      contributions
    });

    const savedGoal = await newGoal.save();
    res.status(201).json({ success: true, data: savedGoal });
  } catch (error) {
    console.error("Create goal error:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// Update a goal
const updateGoal = async (req, res) => {
  try {
    const {
      name,
      description,
      targetAmount,
      currentAmount,
      targetDate,
      category,
      priority,
      isCompleted,
      contributions
    } = req.body;

    // Find goal and check if it belongs to the user
    let goal = await Goal.findOne({
      _id: req.params.id,
      user: req.user.id
    });

    if (!goal) {
      return res.status(404).json({ success: false, message: "Goal not found or not authorized" });
    }

    // Update goal with new data
    goal.name = name || goal.name;
    goal.description = description !== undefined ? description : goal.description;
    goal.targetAmount = targetAmount || goal.targetAmount;
    goal.currentAmount = currentAmount !== undefined ? currentAmount : goal.currentAmount;
    goal.targetDate = targetDate || goal.targetDate;
    goal.category = category || goal.category;
    goal.priority = priority || goal.priority;
    goal.isCompleted = isCompleted !== undefined ? isCompleted : goal.isCompleted;
    
    // Handle contributions if provided
    if (contributions && Array.isArray(contributions)) {
      goal.contributions = contributions;
    }

    const updatedGoal = await goal.save();
    res.json({ success: true, data: updatedGoal });
  } catch (error) {
    console.error("Update goal error:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// Delete a goal
const deleteGoal = async (req, res) => {
  try {
    const goal = await Goal.findOne({
      _id: req.params.id,
      user: req.user.id
    });

    if (!goal) {
      return res.status(404).json({ success: false, message: "Goal not found or not authorized" });
    }

    await goal.deleteOne();
    res.json({ success: true, data: {}, message: "Goal removed" });
  } catch (error) {
    console.error("Delete goal error:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// Update goal progress
const updateGoalProgress = async (req, res) => {
  try {
    const { currentAmount } = req.body;

    if (currentAmount === undefined) {
      return res.status(400).json({ success: false, message: "Current amount is required" });
    }

    const goal = await Goal.findOne({
      _id: req.params.id,
      user: req.user.id
    });

    if (!goal) {
      return res.status(404).json({ success: false, message: "Goal not found or not authorized" });
    }

    goal.currentAmount = currentAmount;
    
    // Auto-update completion status if target is reached
    if (currentAmount >= goal.targetAmount && !goal.isCompleted) {
      goal.isCompleted = true;
    }

    const updatedGoal = await goal.save();
    res.json({ success: true, data: updatedGoal });
  } catch (error) {
    console.error("Update goal progress error:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

module.exports = {
  getGoals,
  getGoalById,
  createGoal,
  updateGoal,
  deleteGoal,
  updateGoalProgress
}; 