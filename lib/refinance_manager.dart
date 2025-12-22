import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:finance_calculator/chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';
import 'refinance_calculations.dart';

class RefinanceManager extends ChangeNotifier {
  final changes = ChangeStack();
  final SharedPreferencesAsync preferences = SharedPreferencesAsync();

  // Current loan properties
  double _remainingBalance = 200000.0;
  double _currentInterestRate = 4.5;
  int _remainingTermMonths = 240; // 20 years

  // New loan properties
  int _newLoanTermYears = 30;
  double _newInterestRate = 3.5;
  double _points = 0.0;
  double _financedFees = 3000.0; // Fees added to loan principal
  double _upfrontFees = 0.0; // Fees paid at closing
  double _cashOutAmount = 0.0;
  double _additionalPrincipalPayment = 0.0;
  double _investmentReturnRate = 7.0; // Annual return rate for opportunity cost
  bool _includeOpportunityCost = true; // Whether to include opportunity cost in total savings

  // Getters for current loan
  double get remainingBalance => _remainingBalance;
  double get currentInterestRate => _currentInterestRate;
  int get remainingTermMonths => _remainingTermMonths;

  // Getters for new loan
  int get newLoanTermYears => _newLoanTermYears;
  double get newInterestRate => _newInterestRate;
  double get points => _points;
  double get financedFees => _financedFees;
  double get upfrontFees => _upfrontFees;
  double get cashOutAmount => _cashOutAmount;
  double get additionalPrincipalPayment => _additionalPrincipalPayment;
  double get investmentReturnRate => _investmentReturnRate;
  bool get includeOpportunityCost => _includeOpportunityCost;

  // Setters for current loan
  set remainingBalance(double value) {
    _remainingBalance = value;
    notifyListeners();
    _saveToPreferences();
  }

  set currentInterestRate(double value) {
    _currentInterestRate = value;
    notifyListeners();
    _saveToPreferences();
  }

  set remainingTermMonths(int value) {
    _remainingTermMonths = value;
    notifyListeners();
    _saveToPreferences();
  }

  // Setters for new loan
  set newLoanTermYears(int value) {
    _newLoanTermYears = value;
    notifyListeners();
    _saveToPreferences();
  }

  set newInterestRate(double value) {
    _newInterestRate = value;
    notifyListeners();
    _saveToPreferences();
  }

  set points(double value) {
    _points = value;
    notifyListeners();
    _saveToPreferences();
  }

  set financedFees(double value) {
    _financedFees = value;
    notifyListeners();
    _saveToPreferences();
  }

  set upfrontFees(double value) {
    _upfrontFees = value;
    notifyListeners();
    _saveToPreferences();
  }

  set cashOutAmount(double value) {
    _cashOutAmount = value;
    notifyListeners();
    _saveToPreferences();
  }

  set additionalPrincipalPayment(double value) {
    _additionalPrincipalPayment = value;
    notifyListeners();
    _saveToPreferences();
  }

  set investmentReturnRate(double value) {
    _investmentReturnRate = value;
    notifyListeners();
    _saveToPreferences();
  }

  set includeOpportunityCost(bool value) {
    _includeOpportunityCost = value;
    notifyListeners();
    _saveToPreferences();
  }

  // Calculation methods
  double calculateNewLoanAmount() {
    return RefinanceCalculations.calculateNewLoanAmount(
      remainingBalance: _remainingBalance,
      cashOutAmount: _cashOutAmount,
      financedFees: _financedFees,
      additionalPrincipalPayment: _additionalPrincipalPayment,
    );
  }

  double calculateCurrentMonthlyPayment() {
    return RefinanceCalculations.calculateMonthlyPayment(
      principal: _remainingBalance,
      annualInterestRate: _currentInterestRate,
      termMonths: _remainingTermMonths,
    );
  }

  double calculateNewMonthlyPayment() {
    return RefinanceCalculations.calculateMonthlyPayment(
      principal: calculateNewLoanAmount(),
      annualInterestRate: _newInterestRate,
      termMonths: _newLoanTermYears * 12,
    );
  }

  // Calculate the APR (Annual Percentage Rate) for the new loan
  // APR includes the effect of fees and points on the effective interest rate
  double calculateNewLoanAPR() {
    final monthlyPayment = calculateNewMonthlyPayment();
    final termMonths = _newLoanTermYears * 12;
    
    // Calculate the actual amount received (principal minus upfront costs)
    double amountFinanced = _remainingBalance + _cashOutAmount;
    // Upfront fees reduce the amount received
    amountFinanced -= _upfrontFees;
    amountFinanced -= _additionalPrincipalPayment;
    
    // Points are always a prepaid finance charge
    final pointsCost = calculatePointsCost();
    amountFinanced -= pointsCost;
    
    // If we're not paying any fees upfront, APR equals the interest rate
    if (pointsCost == 0 && _upfrontFees == 0) {
      return _newInterestRate;
    }
    
    // Use Newton-Raphson method to solve for APR
    // We need to find the rate where: amountFinanced = monthlyPayment * [(1 - (1 + r)^-n) / r]
    double apr = _newInterestRate; // Start with nominal rate
    const maxIterations = 100;
    const tolerance = 0.0001;
    
    for (int i = 0; i < maxIterations; i++) {
      final monthlyRate = apr / 100 / 12;
      if (monthlyRate == 0) break;
      
      final onePlusR = 1 + monthlyRate;
      final discountFactor = (1 - math.pow(onePlusR, -termMonths)) / monthlyRate;
      final pv = monthlyPayment * discountFactor;
      final error = pv - amountFinanced;
      
      if (error.abs() < tolerance) break;
      
      // Calculate derivative for Newton-Raphson
      final dPV = monthlyPayment * (
        (termMonths * math.pow(onePlusR, -termMonths - 1)) / monthlyRate +
        (math.pow(onePlusR, -termMonths) - 1) / (monthlyRate * monthlyRate)
      ) / 12 / 100;
      
      apr = apr - error / dPV;
      
      // Keep APR in reasonable bounds
      if (apr < 0) apr = 0.1;
      if (apr > 50) apr = 50;
    }
    
    return apr;
  }

  double calculatePointsCost() {
    return calculateNewLoanAmount() * (_points / 100);
  }

  double calculateTotalUpfrontCosts() {
    return RefinanceCalculations.calculateUpfrontCosts(
      loanAmount: calculateNewLoanAmount(),
      points: _points,
      upfrontFees: _upfrontFees,
      additionalPrincipalPayment: _additionalPrincipalPayment,
    );
  }

  // Calculate opportunity cost of paying upfront costs
  double calculateOpportunityCost() {
    return RefinanceCalculations.calculateOpportunityCost(
      upfrontCosts: calculateTotalUpfrontCosts(),
      investmentReturnRate: _investmentReturnRate,
      termMonths: _newLoanTermYears * 12,
    );
  }

  double calculateMonthlySavings() {
    return calculateCurrentMonthlyPayment() - calculateNewMonthlyPayment();
  }

  int calculateBreakEvenMonths() {
    final monthlySavings = calculateMonthlySavings();
    if (monthlySavings <= 0) {
      return 0; // No break-even if new payment is higher
    }
    return (calculateTotalUpfrontCosts() / monthlySavings).ceil();
  }

  double calculateTotalInterestCurrent() {
    return RefinanceCalculations.calculateTotalInterest(
      principal: _remainingBalance,
      annualInterestRate: _currentInterestRate,
      termMonths: _remainingTermMonths,
    );
  }

  double calculateTotalInterestNew() {
    final newLoanAmount = calculateNewLoanAmount();
    return RefinanceCalculations.calculateTotalInterest(
      principal: newLoanAmount,
      annualInterestRate: _newInterestRate,
      termMonths: _newLoanTermYears * 12,
    );
  }

  double calculateTotalCostDifference() {
    return RefinanceCalculations.calculateTotalCostDifference(
      remainingBalance: _remainingBalance,
      remainingTermMonths: _remainingTermMonths,
      currentInterestRate: _currentInterestRate,
      newLoanTermYears: _newLoanTermYears,
      newInterestRate: _newInterestRate,
      points: _points,
      financedFees: _financedFees,
      upfrontFees: _upfrontFees,
      cashOutAmount: _cashOutAmount,
      additionalPrincipalPayment: _additionalPrincipalPayment,
      investmentReturnRate: _investmentReturnRate,
      includeOpportunityCost: _includeOpportunityCost,
    );
  }

  bool isRefinanceAdvantageous() {
    // Refinance is advantageous if:
    // 1. Monthly payment decreases OR
    // 2. Total cost over the life of the loan decreases significantly
    final monthlySavings = calculateMonthlySavings();
    final breakEven = calculateBreakEvenMonths();
    final totalSavings = calculateTotalCostDifference();

    // If monthly savings is positive and break-even is within reasonable timeframe
    if (monthlySavings > 0 && breakEven > 0 && breakEven < 60) {
      return true;
    }

    // Or if total cost savings is significant
    if (totalSavings > 5000) {
      return true;
    }

    return false;
  }

  void reset() {
    _remainingBalance = 200000.0;
    _currentInterestRate = 4.5;
    _remainingTermMonths = 240;
    _newLoanTermYears = 30;
    _newInterestRate = 3.5;
    _points = 0.0;
    _financedFees = 3000.0;
    _upfrontFees = 0.0;
    _cashOutAmount = 0.0;
    _additionalPrincipalPayment = 0.0;
    _investmentReturnRate = 7.0;
    _includeOpportunityCost = true;
    notifyListeners();
    _saveToPreferences();
  }

  // Save all values to SharedPreferences
  void _saveToPreferences() async {
    await preferences.setDouble('refinance_remainingBalance', _remainingBalance);
    await preferences.setDouble('refinance_currentInterestRate', _currentInterestRate);
    await preferences.setInt('refinance_remainingTermMonths', _remainingTermMonths);
    await preferences.setInt('refinance_newLoanTermYears', _newLoanTermYears);
    await preferences.setDouble('refinance_newInterestRate', _newInterestRate);
    await preferences.setDouble('refinance_points', _points);
    await preferences.setDouble('refinance_financedFees', _financedFees);
    await preferences.setDouble('refinance_upfrontFees', _upfrontFees);
    await preferences.setDouble('refinance_cashOutAmount', _cashOutAmount);
    await preferences.setDouble('refinance_additionalPrincipalPayment', _additionalPrincipalPayment);
    await preferences.setDouble('refinance_investmentReturnRate', _investmentReturnRate);
    await preferences.setBool('refinance_includeOpportunityCost', _includeOpportunityCost);
  }

  // Load values from SharedPreferences
  Future<void> loadFromPreferences() async {
    _remainingBalance = await preferences.getDouble('refinance_remainingBalance') ?? 200000.0;
    _currentInterestRate = await preferences.getDouble('refinance_currentInterestRate') ?? 4.5;
    _remainingTermMonths = await preferences.getInt('refinance_remainingTermMonths') ?? 240;
    _newLoanTermYears = await preferences.getInt('refinance_newLoanTermYears') ?? 30;
    _newInterestRate = await preferences.getDouble('refinance_newInterestRate') ?? 3.5;
    _points = await preferences.getDouble('refinance_points') ?? 0.0;
    _financedFees = await preferences.getDouble('refinance_financedFees') ?? 3000.0;
    _upfrontFees = await preferences.getDouble('refinance_upfrontFees') ?? 0.0;
    _cashOutAmount = await preferences.getDouble('refinance_cashOutAmount') ?? 0.0;
    _additionalPrincipalPayment = await preferences.getDouble('refinance_additionalPrincipalPayment') ?? 0.0;
    _investmentReturnRate = await preferences.getDouble('refinance_investmentReturnRate') ?? 7.0;
    _includeOpportunityCost = await preferences.getBool('refinance_includeOpportunityCost') ?? true;
    notifyListeners();
  }

  // Calculate chart data for a specific variable
  static ChartData calculateChart({
    required String variableName,
    required double min,
    required double max,
    required int divisions,
    required RefinanceManager manager,
  }) {
    return RefinanceCalculations.calculateChart(
      variableName: variableName,
      min: min,
      max: max,
      divisions: divisions,
      manager: manager,
    );
  }
}

