import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class RefinanceManager extends ChangeNotifier {
  final changes = ChangeStack();
  final SharedPreferencesAsync preferences = SharedPreferencesAsync();

  // Current loan properties
  double _remainingBalance = 200000.0;
  double _currentMonthlyPayment = 1200.0;
  double _currentInterestRate = 4.5;
  int _remainingTermMonths = 240; // 20 years

  // New loan properties
  int _newLoanTermYears = 30;
  double _newInterestRate = 3.5;
  double _points = 0.0;
  double _costsAndFees = 3000.0;
  double _cashOutAmount = 0.0;
  double _additionalPrincipalPayment = 0.0;
  bool _financeCosts = true; // true = finance, false = pay upfront
  double _investmentReturnRate = 7.0; // Annual return rate for opportunity cost
  bool _includeOpportunityCost = true; // Whether to include opportunity cost in total savings

  // Getters for current loan
  double get remainingBalance => _remainingBalance;
  double get currentMonthlyPayment => _currentMonthlyPayment;
  double get currentInterestRate => _currentInterestRate;
  int get remainingTermMonths => _remainingTermMonths;

  // Getters for new loan
  int get newLoanTermYears => _newLoanTermYears;
  double get newInterestRate => _newInterestRate;
  double get points => _points;
  double get costsAndFees => _costsAndFees;
  double get cashOutAmount => _cashOutAmount;
  double get additionalPrincipalPayment => _additionalPrincipalPayment;
  bool get financeCosts => _financeCosts;
  double get investmentReturnRate => _investmentReturnRate;
  bool get includeOpportunityCost => _includeOpportunityCost;

  // Setters for current loan
  set remainingBalance(double value) {
    _remainingBalance = value;
    notifyListeners();
    _saveToPreferences();
  }

  set currentMonthlyPayment(double value) {
    _currentMonthlyPayment = value;
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

  set costsAndFees(double value) {
    _costsAndFees = value;
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

  set financeCosts(bool value) {
    _financeCosts = value;
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
    double loanAmount = _remainingBalance + _cashOutAmount;
    if (_financeCosts) {
      loanAmount += _costsAndFees;
    }
    // Additional principal payment reduces the loan amount
    loanAmount -= _additionalPrincipalPayment;
    return loanAmount;
  }

  double calculateNewMonthlyPayment() {
    final principal = calculateNewLoanAmount();
    final monthlyRate = _newInterestRate / 100 / 12;
    final numPayments = _newLoanTermYears * 12;

    if (monthlyRate == 0) {
      return principal / numPayments;
    }

    return principal *
        (monthlyRate * pow(1 + monthlyRate, numPayments)) /
        (pow(1 + monthlyRate, numPayments) - 1);
  }

  double calculatePointsCost() {
    return _remainingBalance * (_points / 100);
  }

  double calculateTotalUpfrontCosts() {
    double upfrontCosts = calculatePointsCost();
    if (!_financeCosts) {
      upfrontCosts += _costsAndFees;
    }
    // Additional principal payment is always paid upfront
    upfrontCosts += _additionalPrincipalPayment;
    return upfrontCosts;
  }

  // Calculate opportunity cost of paying upfront costs
  double calculateOpportunityCost() {
    double upfrontAmount = calculatePointsCost() + _additionalPrincipalPayment;
    if (!_financeCosts) {
      upfrontAmount += _costsAndFees;
    }
    
    if (upfrontAmount == 0) {
      return 0.0;
    }
    
    final monthlyRate = _investmentReturnRate / 100 / 12;
    final numMonths = _newLoanTermYears * 12;
    
    // Future value of upfront costs if invested
    if (monthlyRate == 0) {
      return 0.0;
    }
    final futureValue = upfrontAmount * pow(1 + monthlyRate, numMonths);
    return futureValue - upfrontAmount;
  }

  double calculateMonthlySavings() {
    return _currentMonthlyPayment - calculateNewMonthlyPayment();
  }

  int calculateBreakEvenMonths() {
    final monthlySavings = calculateMonthlySavings();
    if (monthlySavings <= 0) {
      return -1; // No break-even if new payment is higher
    }
    return (calculateTotalUpfrontCosts() / monthlySavings).ceil();
  }

  double calculateTotalInterestCurrent() {
    return (_currentMonthlyPayment * _remainingTermMonths) - _remainingBalance;
  }

  double calculateTotalInterestNew() {
    final newPayment = calculateNewMonthlyPayment();
    final totalPaid = newPayment * _newLoanTermYears * 12;
    return totalPaid - calculateNewLoanAmount();
  }

  double calculateTotalCostDifference() {
    final currentTotalCost = calculateTotalInterestCurrent() + _remainingBalance;
    final opportunityCost = _includeOpportunityCost ? calculateOpportunityCost() : 0.0;
    final newTotalCost = calculateTotalInterestNew() +
        calculateNewLoanAmount() +
        calculateTotalUpfrontCosts() +
        opportunityCost -
        _cashOutAmount;
    return currentTotalCost - newTotalCost;
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
    _currentMonthlyPayment = 1200.0;
    _currentInterestRate = 4.5;
    _remainingTermMonths = 240;
    _newLoanTermYears = 30;
    _newInterestRate = 3.5;
    _points = 0.0;
    _costsAndFees = 3000.0;
    _cashOutAmount = 0.0;
    _additionalPrincipalPayment = 0.0;
    _financeCosts = true;
    _investmentReturnRate = 7.0;
    _includeOpportunityCost = true;
    notifyListeners();
    _saveToPreferences();
  }

  // Save all values to SharedPreferences
  void _saveToPreferences() async {
    await preferences.setDouble('refinance_remainingBalance', _remainingBalance);
    await preferences.setDouble('refinance_currentMonthlyPayment', _currentMonthlyPayment);
    await preferences.setDouble('refinance_currentInterestRate', _currentInterestRate);
    await preferences.setInt('refinance_remainingTermMonths', _remainingTermMonths);
    await preferences.setInt('refinance_newLoanTermYears', _newLoanTermYears);
    await preferences.setDouble('refinance_newInterestRate', _newInterestRate);
    await preferences.setDouble('refinance_points', _points);
    await preferences.setDouble('refinance_costsAndFees', _costsAndFees);
    await preferences.setDouble('refinance_cashOutAmount', _cashOutAmount);
    await preferences.setDouble('refinance_additionalPrincipalPayment', _additionalPrincipalPayment);
    await preferences.setBool('refinance_financeCosts', _financeCosts);
    await preferences.setDouble('refinance_investmentReturnRate', _investmentReturnRate);
    await preferences.setBool('refinance_includeOpportunityCost', _includeOpportunityCost);
  }

  // Load values from SharedPreferences
  Future<void> loadFromPreferences() async {
    _remainingBalance = await preferences.getDouble('refinance_remainingBalance') ?? 200000.0;
    _currentMonthlyPayment = await preferences.getDouble('refinance_currentMonthlyPayment') ?? 1200.0;
    _currentInterestRate = await preferences.getDouble('refinance_currentInterestRate') ?? 4.5;
    _remainingTermMonths = await preferences.getInt('refinance_remainingTermMonths') ?? 240;
    _newLoanTermYears = await preferences.getInt('refinance_newLoanTermYears') ?? 30;
    _newInterestRate = await preferences.getDouble('refinance_newInterestRate') ?? 3.5;
    _points = await preferences.getDouble('refinance_points') ?? 0.0;
    _costsAndFees = await preferences.getDouble('refinance_costsAndFees') ?? 3000.0;
    _cashOutAmount = await preferences.getDouble('refinance_cashOutAmount') ?? 0.0;
    _additionalPrincipalPayment = await preferences.getDouble('refinance_additionalPrincipalPayment') ?? 0.0;
    _financeCosts = await preferences.getBool('refinance_financeCosts') ?? true;
    _investmentReturnRate = await preferences.getDouble('refinance_investmentReturnRate') ?? 7.0;
    _includeOpportunityCost = await preferences.getBool('refinance_includeOpportunityCost') ?? true;
    notifyListeners();
  }
}

// Helper function for power calculation
double pow(double base, int exponent) {
  double result = 1;
  for (int i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}
