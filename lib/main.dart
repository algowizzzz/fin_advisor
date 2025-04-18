import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/income_screen.dart';
import 'screens/income_form_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/add_expense_screen.dart';
import 'screens/expense_form_screen.dart';
import 'screens/assets_screen.dart';
import 'screens/asset_form_screen.dart';
import 'screens/liabilities_screen.dart';
import 'screens/liability_form_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/goal_form_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Try to discover backend port on startup
  final apiService = ApiService();
  await apiService.discoverBackendPort();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
      ],
      child: MaterialApp(
        title: 'Financial Advisor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0073CF), // Primary blue color
            primary: const Color(0xFF0073CF),
            secondary: const Color(0xFF00A3E0),
            background: Colors.white,
          ),
          textTheme: TextTheme(
            // Provide default text styles that don't depend on Google Fonts
            bodyLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
            bodyMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            titleMedium: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ).apply(
            fontFamily: 'Roboto', // Default font family as fallback
          ),
          useMaterial3: true,
          buttonTheme: const ButtonThemeData(
            buttonColor: Color(0xFF0073CF),
            textTheme: ButtonTextTheme.primary,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0073CF),
            foregroundColor: Colors.white,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const DashboardScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/onboarding': (context) => OnboardingScreen(
            userId: ModalRoute.of(context)?.settings.arguments as dynamic ?? '',
            token: '',
          ),
          '/profile': (context) => const ProfileScreen(),
          '/income': (context) => const IncomeScreen(),
          '/add-income': (context) => const IncomeFormScreen(),
          '/edit-income': (context) => IncomeFormScreen(income: ModalRoute.of(context)?.settings.arguments as dynamic),
          '/expenses': (context) => const ExpensesScreen(),
          '/add-expense': (context) => const AddExpenseScreen(),
          '/edit-expense': (context) => ExpenseFormScreen(expense: ModalRoute.of(context)?.settings.arguments as dynamic),
          '/assets': (context) => const AssetsScreen(),
          '/add-asset': (context) => const AssetFormScreen(),
          '/edit-asset': (context) => AssetFormScreen(asset: ModalRoute.of(context)?.settings.arguments as dynamic),
          '/liabilities': (context) => const LiabilitiesScreen(),
          '/add-liability': (context) => const LiabilityFormScreen(),
          '/edit-liability': (context) => LiabilityFormScreen(liability: ModalRoute.of(context)?.settings.arguments as dynamic),
          '/goals': (context) => const GoalsScreen(),
          '/add-goal': (context) => const GoalFormScreen(),
          '/edit-goal': (context) => GoalFormScreen(goal: ModalRoute.of(context)?.settings.arguments as dynamic),
        },
      ),
    );
  }
} 