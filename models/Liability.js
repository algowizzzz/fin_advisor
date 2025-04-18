const mongoose = require('mongoose');

const LiabilitySchema = new mongoose.Schema({
  user: { 
    type: mongoose.Schema.Types.Mixed, 
    ref: 'User', 
    required: true 
  },
  name: { 
    type: String, 
    required: true 
  },
  type: { 
    type: String, 
    required: true,
    enum: ['Credit Card', 'Mortgage', 'Auto Loan', 'Student Loan', 'Personal Loan', 'Medical Debt', 'Other']
  },
  amount: { 
    type: Number, 
    required: true 
  },
  interestRate: {
    type: Number,
    required: true,
    min: 0
  },
  startDate: { 
    type: Date, 
    required: true
  },
  dueDate: { 
    type: Date, 
    required: true
  },
  lender: { 
    type: String 
  },
  description: { 
    type: String 
  },
  isFixed: {
    type: Boolean,
    default: true
  },
  minimumPayment: {
    type: Number,
    min: 0
  },
  remainingPayments: {
    type: Number,
    min: 0
  }
}, { 
  timestamps: true 
});

const Liability = mongoose.model('Liability', LiabilitySchema);
module.exports = Liability; 