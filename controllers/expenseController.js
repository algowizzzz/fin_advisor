const Expense = require('../models/Expense');

// @desc    Get all expenses for logged in user
// @route   GET /api/expenses
// @access  Private
const getExpenses = async (req, res) => {
  try {
    const expenses = await Expense.find({ user: req.user.id });
    res.json({ success: true, data: expenses });
  } catch (error) {
    console.error('Get expenses error:', error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// @desc    Add new expense
// @route   POST /api/expenses
// @access  Private
const addExpense = async (req, res) => {
  try {
    const { title, category, amount, frequency, durationMonths, isRecurring, date, description } = req.body;
    
    const expense = new Expense({
      user: req.user.id,
      title,
      category,
      amount,
      frequency,
      durationMonths,
      isRecurring,
      date: date || Date.now(),
      description
    });
    
    const savedExpense = await expense.save();
    res.status(201).json({ success: true, data: savedExpense });
  } catch (error) {
    console.error('Add expense error:', error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// @desc    Update expense
// @route   PUT /api/expenses/:id
// @access  Private
const updateExpense = async (req, res) => {
  try {
    const expense = await Expense.findById(req.params.id);
    
    if (!expense) {
      return res.status(404).json({ success: false, message: "Expense not found" });
    }
    
    // Check if expense belongs to logged in user
    if (expense.user.toString() !== req.user.id) {
      return res.status(401).json({ success: false, message: "Not authorized" });
    }
    
    const updatedExpense = await Expense.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );
    
    res.json({ success: true, data: updatedExpense });
  } catch (error) {
    console.error('Update expense error:', error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// @desc    Delete expense
// @route   DELETE /api/expenses/:id
// @access  Private
const deleteExpense = async (req, res) => {
  try {
    const expense = await Expense.findById(req.params.id);
    
    if (!expense) {
      return res.status(404).json({ success: false, message: "Expense not found" });
    }
    
    // Check if expense belongs to logged in user
    if (expense.user.toString() !== req.user.id) {
      return res.status(401).json({ success: false, message: "Not authorized" });
    }
    
    await expense.deleteOne();
    
    res.json({ success: true, message: "Expense removed" });
  } catch (error) {
    console.error('Delete expense error:', error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

module.exports = {
  getExpenses,
  addExpense,
  updateExpense,
  deleteExpense
}; 