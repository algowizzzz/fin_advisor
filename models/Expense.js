const mongoose = require('mongoose');

const ExpenseSchema = new mongoose.Schema({
  user: { 
    type: mongoose.Schema.Types.Mixed, 
    ref: 'User', 
    required: true 
  },
  title: { 
    type: String, 
    required: true 
  },
  category: { 
    type: String, 
    required: true 
  },
  amount: { 
    type: Number, 
    required: true 
  },
  frequency: { 
    type: String, 
    enum: ['one-time', 'daily', 'weekly', 'bi-weekly', 'monthly', 'quarterly', 'annually'], 
    default: 'monthly' 
  },
  durationMonths: { 
    type: Number 
  },
  isRecurring: { 
    type: Boolean, 
    default: true 
  },
  date: { 
    type: Date, 
    default: Date.now 
  },
  description: { 
    type: String 
  }
}, { 
  timestamps: true 
});

const Expense = mongoose.model('Expense', ExpenseSchema);
module.exports = Expense;
