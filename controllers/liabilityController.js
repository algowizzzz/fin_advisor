const Liability = require('../models/Liability');

// @desc    Get all liabilities for logged in user
// @route   GET /api/liabilities
// @access  Private
const getLiabilities = async (req, res) => {
  try {
    const liabilities = await Liability.find({ user: req.user.id });
    res.json({ success: true, data: liabilities });
  } catch (error) {
    console.error('Get liabilities error:', error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// @desc    Add new liability
// @route   POST /api/liabilities
// @access  Private
const addLiability = async (req, res) => {
  try {
    const { name, type, amount, interestRate, startDate, dueDate, lender, description, isFixed, minimumPayment, remainingPayments } = req.body;
    
    const liability = new Liability({
      user: req.user.id,
      name,
      type,
      amount,
      interestRate,
      startDate: startDate || Date.now(),
      dueDate,
      lender,
      description,
      isFixed,
      minimumPayment,
      remainingPayments
    });
    
    const savedLiability = await liability.save();
    res.status(201).json({ success: true, data: savedLiability });
  } catch (error) {
    console.error('Add liability error:', error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// @desc    Update liability
// @route   PUT /api/liabilities/:id
// @access  Private
const updateLiability = async (req, res) => {
  try {
    const liability = await Liability.findById(req.params.id);
    
    if (!liability) {
      return res.status(404).json({ success: false, message: "Liability not found" });
    }
    
    // Check if liability belongs to logged in user
    if (liability.user.toString() !== req.user.id) {
      return res.status(401).json({ success: false, message: "Not authorized" });
    }
    
    const updatedLiability = await Liability.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );
    
    res.json({ success: true, data: updatedLiability });
  } catch (error) {
    console.error('Update liability error:', error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// @desc    Delete liability
// @route   DELETE /api/liabilities/:id
// @access  Private
const deleteLiability = async (req, res) => {
  try {
    const liability = await Liability.findById(req.params.id);
    
    if (!liability) {
      return res.status(404).json({ success: false, message: "Liability not found" });
    }
    
    // Check if liability belongs to logged in user
    if (liability.user.toString() !== req.user.id) {
      return res.status(401).json({ success: false, message: "Not authorized" });
    }
    
    await liability.deleteOne();
    
    res.json({ success: true, message: "Liability removed" });
  } catch (error) {
    console.error('Delete liability error:', error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

module.exports = {
  getLiabilities,
  addLiability,
  updateLiability,
  deleteLiability
}; 