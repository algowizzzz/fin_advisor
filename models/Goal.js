const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const GoalSchema = new Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  name: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    trim: true
  },
  targetAmount: {
    type: Number,
    required: true,
    min: 0
  },
  currentAmount: {
    type: Number,
    default: 0,
    min: 0
  },
  targetDate: {
    type: Date,
    required: true
  },
  startDate: {
    type: Date,
    default: Date.now
  },
  category: {
    type: String,
    enum: ['Retirement', 'Education', 'Home', 'Car', 'Travel', 'Emergency Fund', 'Debt Payoff', 'Investment', 'Other'],
    default: 'Other'
  },
  priority: {
    type: Number,
    enum: [1, 2, 3], // 1: High, 2: Medium, 3: Low
    default: 2
  },
  isCompleted: {
    type: Boolean,
    default: false
  },
  contributions: [{
    amount: Number,
    date: {
      type: Date,
      default: Date.now
    },
    note: String
  }]
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Virtual properties
GoalSchema.virtual('progressPercentage').get(function() {
  return this.targetAmount > 0 ? (this.currentAmount / this.targetAmount) * 100 : 0;
});

GoalSchema.virtual('daysRemaining').get(function() {
  const now = new Date();
  const diff = this.targetDate - now;
  return Math.ceil(diff / (1000 * 60 * 60 * 24));
});

GoalSchema.virtual('isOverdue').get(function() {
  return !this.isCompleted && this.daysRemaining < 0;
});

module.exports = mongoose.model('Goal', GoalSchema); 