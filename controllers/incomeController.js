const Income = require('../models/Income');

// @desc    Get all incomes for logged in user
// @route   GET /api/incomes
// @access  Private
const getIncomes = async (req, res) => {
  try {
    const incomes = await Income.find({ user: req.user.id });
    res.json({ success: true, data: incomes });
  } catch (error) {
    console.error('Get incomes error:', error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// @desc    Add new income
// @route   POST /api/incomes
// @access  Private
const addIncome = async (req, res) => {
  try {
    const { source, amount, frequency, date, description, category, isRecurring } = req.body;
    
    const income = new Income({
      user: req.user.id,
      source,
      amount,
      frequency,
      date: date || Date.now(),
      description,
      category,
      isRecurring
    });
    
    const savedIncome = await income.save();
    res.status(201).json({ success: true, data: savedIncome });
  } catch (error) {
    console.error('Add income error:', error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// @desc    Update income
// @route   PUT /api/incomes/:id
// @access  Private
const updateIncome = async (req, res) => {
  try {
    const income = await Income.findById(req.params.id);
    
    if (!income) {
      return res.status(404).json({ success: false, message: "Income not found" });
    }
    
    // Check if income belongs to logged in user
    if (income.user.toString() !== req.user.id) {
      return res.status(401).json({ success: false, message: "Not authorized" });
    }
    
    const updatedIncome = await Income.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );
    
    res.json({ success: true, data: updatedIncome });
  } catch (error) {
    console.error('Update income error:', error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// @desc    Delete income
// @route   DELETE /api/incomes/:id
// @access  Private
const deleteIncome = async (req, res) => {
  try {
    const income = await Income.findById(req.params.id);
    
    if (!income) {
      return res.status(404).json({ success: false, message: "Income not found" });
    }
    
    // Check if income belongs to logged in user
    if (income.user.toString() !== req.user.id) {
      return res.status(401).json({ success: false, message: "Not authorized" });
    }
    
    await income.deleteOne();
    
    res.json({ success: true, message: "Income removed" });
  } catch (error) {
    console.error('Delete income error:', error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

module.exports = {
  getIncomes,
  addIncome,
  updateIncome,
  deleteIncome
}; 