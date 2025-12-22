import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finance_calculator/landing_page.dart';
import 'package:finance_calculator/refinance_page.dart';
import 'package:finance_calculator/rent_vs_buy_page.dart';
import 'package:finance_calculator/rent_vs_buy_manager.dart';

void main() {
  var uri = Uri.base;
  var rentVsBuyManager = RentVsBuyManager();
  rentVsBuyManager.onInit(uri);
  runApp(
    ChangeNotifierProvider(
      create: (context) => rentVsBuyManager,
      child: const FinanceCalculatorApp(),
    ),
  );
}

class FinanceCalculatorApp extends StatelessWidget {
  const FinanceCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance Calculator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const LandingPage(),
      onGenerateRoute: generateRoute,
    );
  }
}

Route<dynamic> generateRoute(RouteSettings settings) {
  final routeName = settings.name ?? '';
  
  if (routeName == '/refinance') {
    return MaterialPageRoute(
      settings: RouteSettings(name: routeName),
      builder: (context) {
        return const RefinancePage();
      },
    );
  }
  
  if (routeName == '/rent-vs-buy') {
    return MaterialPageRoute(
      settings: RouteSettings(name: routeName),
      builder: (context) {
        return const RentVsBuyPage();
      },
    );
  }
  
  return MaterialPageRoute(
    settings: RouteSettings(name: routeName),
    builder: (context) {
      return const LandingPage();
    },
  );
}
