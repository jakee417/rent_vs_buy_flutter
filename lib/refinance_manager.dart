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
  double _totalFees = 3000.0; // Total closing fees
  double _percentageFinanced =
      1.0; // Percentage of fees that are financed (0-1)
  double _cashOutAmount = 0.0;
  double _additionalPrincipalPayment = 0.0;
  double _investmentReturnRate = 7.0; // Annual return rate for opportunity cost
  bool _includeOpportunityCost =
      true; // Whether to include opportunity cost in total savings

  // Home sale simulation
  int _monthsUntilSale = 120; // Months until home is sold (0-360)

  // Getters for current loan
  double get remainingBalance => _remainingBalance;
  double get currentInterestRate => _currentInterestRate;
  int get remainingTermMonths => _remainingTermMonths;

  // Getters for new loan
  int get newLoanTermYears => _newLoanTermYears;
  double get newInterestRate => _newInterestRate;
  double get points => _points;
  double get totalFees => _totalFees;
  double get percentageFinanced => _percentageFinanced;
  // Total closing costs including points and other fees
  double get totalClosingCosts => _resolveAll().totalClosingCosts;
  // Computed getters: financedFees and upfrontFees include points in the pool
  double get financedFees => _resolveAll().financedFees;
  double get upfrontFees => _resolveAll().upfrontFees;

  // Resolve the circular dependency between points, loan amount, and fees
  ({
    double newLoanAmount,
    double financedFees,
    double upfrontFees,
    double pointsCost,
    double totalClosingCosts
  }) _resolveAll() {
    return RefinanceCalculations.resolveFeesAndLoanAmount(
      remainingBalance: _remainingBalance,
      cashOutAmount: _cashOutAmount,
      additionalPrincipalPayment: _additionalPrincipalPayment,
      otherClosingCosts: _totalFees,
      pointsPercent: _points,
      percentageFinanced: _percentageFinanced,
    );
  }

  double get cashOutAmount => _cashOutAmount;
  double get additionalPrincipalPayment => _additionalPrincipalPayment;
  double get investmentReturnRate => _investmentReturnRate;
  bool get includeOpportunityCost => _includeOpportunityCost;
  int get monthsUntilSale => _monthsUntilSale;

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

  set totalFees(double value) {
    _totalFees = value;
    notifyListeners();
    _saveToPreferences();
  }

  set percentageFinanced(double value) {
    _percentageFinanced = value;
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

  set monthsUntilSale(int value) {
    _monthsUntilSale = value;
    notifyListeners();
    _saveToPreferences();
  }

  // Calculation methods
  double calculateNewLoanAmount() {
    return _resolveAll().newLoanAmount;
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
    // upfrontFees now includes the upfront portion of points
    double amountFinanced = _remainingBalance + _cashOutAmount;
    amountFinanced -= upfrontFees;
    amountFinanced -= _additionalPrincipalPayment;

    // If nothing is paid upfront, APR equals the interest rate
    if (upfrontFees == 0) {
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
      final discountFactor =
          (1 - math.pow(onePlusR, -termMonths)) / monthlyRate;
      final pv = monthlyPayment * discountFactor;
      final error = pv - amountFinanced;

      if (error.abs() < tolerance) break;

      // Calculate derivative for Newton-Raphson
      final dPV = monthlyPayment *
          ((termMonths * math.pow(onePlusR, -termMonths - 1)) / monthlyRate +
              (math.pow(onePlusR, -termMonths) - 1) /
                  (monthlyRate * monthlyRate)) /
          12 /
          100;

      apr = apr - error / dPV;

      // Keep APR in reasonable bounds
      if (apr < 0) apr = 0.1;
      if (apr > 50) apr = 50;
    }

    return apr;
  }

  double calculatePointsCost() {
    return _resolveAll().pointsCost;
  }

  double calculateTotalUpfrontCosts() {
    return RefinanceCalculations.calculateUpfrontCosts(
      upfrontFees: upfrontFees,
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
      otherClosingCosts: _totalFees,
      pointsPercent: _points,
      percentageFinanced: _percentageFinanced,
      cashOutAmount: _cashOutAmount,
      additionalPrincipalPayment: _additionalPrincipalPayment,
      investmentReturnRate: _investmentReturnRate,
      includeOpportunityCost: _includeOpportunityCost,
      monthsUntilSale: _monthsUntilSale,
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
    _totalFees = 3000.0;
    _percentageFinanced = 1.0;
    _cashOutAmount = 0.0;
    _additionalPrincipalPayment = 0.0;
    _investmentReturnRate = 7.0;
    _includeOpportunityCost = true;
    _monthsUntilSale = 120;
    notifyListeners();
    _saveToPreferences();
  }

  // Save all values to SharedPreferences
  void _saveToPreferences() async {
    await preferences.setDouble(
        'refinance_remainingBalance', _remainingBalance);
    await preferences.setDouble(
        'refinance_currentInterestRate', _currentInterestRate);
    await preferences.setInt(
        'refinance_remainingTermMonths', _remainingTermMonths);
    await preferences.setInt('refinance_newLoanTermYears', _newLoanTermYears);
    await preferences.setDouble('refinance_newInterestRate', _newInterestRate);
    await preferences.setDouble('refinance_points', _points);
    await preferences.setDouble('refinance_totalFees', _totalFees);
    await preferences.setDouble(
        'refinance_percentageFinanced', _percentageFinanced);
    await preferences.setDouble('refinance_cashOutAmount', _cashOutAmount);
    await preferences.setDouble(
        'refinance_additionalPrincipalPayment', _additionalPrincipalPayment);
    await preferences.setDouble(
        'refinance_investmentReturnRate', _investmentReturnRate);
    await preferences.setBool(
        'refinance_includeOpportunityCost', _includeOpportunityCost);
    await preferences.setInt('refinance_monthsUntilSale', _monthsUntilSale);
  }

  // Load values from SharedPreferences
  Future<void> loadFromPreferences() async {
    _remainingBalance =
        await preferences.getDouble('refinance_remainingBalance') ?? 200000.0;
    _currentInterestRate =
        await preferences.getDouble('refinance_currentInterestRate') ?? 4.5;
    _remainingTermMonths =
        await preferences.getInt('refinance_remainingTermMonths') ?? 240;
    _newLoanTermYears =
        await preferences.getInt('refinance_newLoanTermYears') ?? 30;
    _newInterestRate =
        await preferences.getDouble('refinance_newInterestRate') ?? 3.5;
    _points = await preferences.getDouble('refinance_points') ?? 0.0;
    _totalFees = await preferences.getDouble('refinance_totalFees') ?? 3000.0;
    _percentageFinanced =
        await preferences.getDouble('refinance_percentageFinanced') ?? 1.0;
    _cashOutAmount =
        await preferences.getDouble('refinance_cashOutAmount') ?? 0.0;
    _additionalPrincipalPayment =
        await preferences.getDouble('refinance_additionalPrincipalPayment') ??
            0.0;
    _investmentReturnRate =
        await preferences.getDouble('refinance_investmentReturnRate') ?? 7.0;
    _includeOpportunityCost =
        await preferences.getBool('refinance_includeOpportunityCost') ?? true;
    _monthsUntilSale =
        await preferences.getInt('refinance_monthsUntilSale') ?? 120;
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
