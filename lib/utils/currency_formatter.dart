import 'package:intl/intl.dart';

class CurrencyFormatter {
  final NumberFormat _formatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 2,
  );

  String format(double amount) {
    return _formatter.format(amount);
  }

  String formatCompact(double amount) {
    if (amount >= 1000000) {
      return '\$${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount);
  }

  double parse(String text) {
    try {
      return _formatter.parse(text).toDouble();
    } catch (e) {
      return 0.0;
    }
  }
} 