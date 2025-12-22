import 'dart:math' as math;
import 'package:ml_linalg/linalg.dart';
import 'chart.dart';
import 'refinance_manager.dart';
import 'utils.dart';

/// Represents a single month in the refinance comparison breakdown
class MonthlyBreakdown {
  final int month;
  final double currentLoanBalance;
  final double currentLoanPayment;
  final double currentLoanInterest;
  final double currentLoanPrincipal;
  final double newLoanBalance;
  final double newLoanPayment;
  final double newLoanInterest;
  final double newLoanPrincipal;
  final double monthlySavings;
  final double cumulativeSavings;

  MonthlyBreakdown({
    required this.month,
    required this.currentLoanBalance,
    required this.currentLoanPayment,
    required this.currentLoanInterest,
    required this.currentLoanPrincipal,
    required this.newLoanBalance,
    required this.newLoanPayment,
    required this.newLoanInterest,
    required this.newLoanPrincipal,
    required this.monthlySavings,
    required this.cumulativeSavings,
  });
}

/// Static calculation methods for refinance analysis
class RefinanceCalculations {
  // Static helper to calculate monthly payment
  static double calculateMonthlyPayment({
    required double principal,
    required double annualInterestRate,
    required int termMonths,
  }) {
    final monthlyRate = annualInterestRate / 100 / 12;

    if (monthlyRate == 0) {
      return principal / termMonths;
    }

    return principal *
        (monthlyRate * pow(1 + monthlyRate, termMonths)) /
        (pow(1 + monthlyRate, termMonths) - 1);
  }

  static double calculateNewLoanAmount({
    required double remainingBalance,
    required double cashOutAmount,
    required double financedFees,
    required double additionalPrincipalPayment,
  }) {
    double loanAmount = remainingBalance + cashOutAmount;
    loanAmount += financedFees;
    loanAmount -= additionalPrincipalPayment;
    return loanAmount;
  }

  static double calculateTotalInterest({
    required double principal,
    required double annualInterestRate,
    required int termMonths,
  }) {
    final monthlyPayment = calculateMonthlyPayment(
      principal: principal,
      annualInterestRate: annualInterestRate,
      termMonths: termMonths,
    );
    return (monthlyPayment * termMonths) - principal;
  }

  static double calculateUpfrontCosts({
    required double loanAmount,
    required double points,
    required double upfrontFees,
    required double additionalPrincipalPayment,
  }) {
    final pointsCost = loanAmount * (points / 100);
    double upfrontCosts = pointsCost;
    upfrontCosts += upfrontFees;
    upfrontCosts += additionalPrincipalPayment;
    return upfrontCosts;
  }

  static double calculateOpportunityCost({
    required double upfrontCosts,
    required double investmentReturnRate,
    required int termMonths,
  }) {
    if (upfrontCosts == 0) {
      return 0.0;
    }

    final monthlyRate = investmentReturnRate / 100 / 12;

    if (monthlyRate == 0) {
      return 0.0;
    }

    final futureValue = upfrontCosts * pow(1 + monthlyRate, termMonths);
    return futureValue - upfrontCosts;
  }

  static double calculateTotalCostDifference({
    required double remainingBalance,
    required int remainingTermMonths,
    required double currentInterestRate,
    required int newLoanTermYears,
    required double newInterestRate,
    required double points,
    required double financedFees,
    required double upfrontFees,
    required double cashOutAmount,
    required double additionalPrincipalPayment,
    required double investmentReturnRate,
    required bool includeOpportunityCost,
  }) {
    final numPayments = newLoanTermYears * 12;

    // Calculate new loan amount using static helper
    final newLoanAmount = calculateNewLoanAmount(
      remainingBalance: remainingBalance,
      cashOutAmount: cashOutAmount,
      financedFees: financedFees,
      additionalPrincipalPayment: additionalPrincipalPayment,
    );

    // Calculate total interest for current loan using static helper
    final totalInterestCurrent = calculateTotalInterest(
      principal: remainingBalance,
      annualInterestRate: currentInterestRate,
      termMonths: remainingTermMonths,
    );

    // Calculate total interest for new loan using static helper
    final totalInterestNew = calculateTotalInterest(
      principal: newLoanAmount,
      annualInterestRate: newInterestRate,
      termMonths: numPayments,
    );

    // Calculate upfront costs using static helper
    final upfrontCosts = calculateUpfrontCosts(
      loanAmount: newLoanAmount,
      points: points,
      upfrontFees: upfrontFees,
      additionalPrincipalPayment: additionalPrincipalPayment,
    );

    // Calculate opportunity cost using static helper
    final opportunityCost = includeOpportunityCost
        ? calculateOpportunityCost(
            upfrontCosts: upfrontCosts,
            investmentReturnRate: investmentReturnRate,
            termMonths: numPayments,
          )
        : 0.0;

    // Calculate total cost difference
    final currentTotalCost = totalInterestCurrent + remainingBalance;
    final newTotalCost = totalInterestNew +
        newLoanAmount +
        upfrontCosts +
        opportunityCost -
        cashOutAmount;

    return currentTotalCost - newTotalCost;
  }

  // Calculate what the remaining balance would be at a different point in the loan
  static double calculateRemainingBalance({
    required double currentBalance,
    required int currentTermMonths,
    required double annualInterestRate,
    required int targetTermMonths,
  }) {
    // If target term is longer (earlier in the loan), we need to calculate backwards
    // If target term is shorter (later in the loan), calculate forward

    if (targetTermMonths == currentTermMonths) {
      return currentBalance;
    }

    final monthlyRate = annualInterestRate / 100 / 12;
    if (monthlyRate == 0) {
      // Simple linear amortization if no interest
      final monthsPassed = currentTermMonths - targetTermMonths;
      return currentBalance -
          (monthsPassed * (currentBalance / currentTermMonths));
    }

    // Calculate the monthly payment based on current situation
    final monthlyPayment = calculateMonthlyPayment(
      principal: currentBalance,
      annualInterestRate: annualInterestRate,
      termMonths: currentTermMonths,
    );

    // Calculate remaining balance at target term using standard formula
    // Remaining balance = P * (1 + r)^p - M * [(1 + r)^p - 1] / r
    // Where p = payments made (currentTerm - targetTerm)
    final monthsPassed = currentTermMonths - targetTermMonths;

    if (monthsPassed < 0) {
      // Target term is further out - balance would have been higher
      // This is going backwards in time, which doesn't make physical sense
      // Return current balance as best approximation
      return currentBalance;
    }

    // Calculate balance after making payments for monthsPassed months
    final onePlusR = 1 + monthlyRate;
    final balance = currentBalance * math.pow(onePlusR, monthsPassed) -
        monthlyPayment * ((math.pow(onePlusR, monthsPassed) - 1) / monthlyRate);

    return balance;
  }

  // Calculate chart data for a specific variable
  static ChartData calculateChart({
    required String variableName,
    required double min,
    required double max,
    required int divisions,
    required RefinanceManager manager,
  }) {
    const maxLength = 80;
    final numPoints = math.min(maxLength, divisions);

    List<ChartSpot> spots = [];
    final step = (max - min) / numPoints;

    for (int i = 0; i <= numPoints; i++) {
      final gridValue = min + (step * i);

      // Create a temporary manager with the current value
      double totalSavings;

      switch (variableName) {
        case 'remainingTermMonths':
          // Calculate what the remaining balance would be at this term
          final adjustedBalance = calculateRemainingBalance(
            currentBalance: manager.remainingBalance,
            currentTermMonths: manager.remainingTermMonths,
            annualInterestRate: manager.currentInterestRate,
            targetTermMonths: gridValue.round(),
          );
          totalSavings = calculateTotalCostDifference(
            remainingBalance: adjustedBalance,
            remainingTermMonths: gridValue.round(),
            currentInterestRate: manager.currentInterestRate,
            newLoanTermYears: manager.newLoanTermYears,
            newInterestRate: manager.newInterestRate,
            points: manager.points,
            financedFees: manager.financedFees,
            upfrontFees: manager.upfrontFees,
            cashOutAmount: manager.cashOutAmount,
            additionalPrincipalPayment: manager.additionalPrincipalPayment,
            investmentReturnRate: manager.investmentReturnRate,
            includeOpportunityCost: manager.includeOpportunityCost,
          );
          break;
        case 'newLoanTermYears':
          totalSavings = calculateTotalCostDifference(
            remainingBalance: manager.remainingBalance,
            remainingTermMonths: manager.remainingTermMonths,
            currentInterestRate: manager.currentInterestRate,
            newLoanTermYears: gridValue.round(),
            newInterestRate: manager.newInterestRate,
            points: manager.points,
            financedFees: manager.financedFees,
            upfrontFees: manager.upfrontFees,
            cashOutAmount: manager.cashOutAmount,
            additionalPrincipalPayment: manager.additionalPrincipalPayment,
            investmentReturnRate: manager.investmentReturnRate,
            includeOpportunityCost: manager.includeOpportunityCost,
          );
          break;
        case 'newInterestRate':
          totalSavings = calculateTotalCostDifference(
            remainingBalance: manager.remainingBalance,
            remainingTermMonths: manager.remainingTermMonths,
            currentInterestRate: manager.currentInterestRate,
            newLoanTermYears: manager.newLoanTermYears,
            newInterestRate: gridValue,
            points: manager.points,
            financedFees: manager.financedFees,
            upfrontFees: manager.upfrontFees,
            cashOutAmount: manager.cashOutAmount,
            additionalPrincipalPayment: manager.additionalPrincipalPayment,
            investmentReturnRate: manager.investmentReturnRate,
            includeOpportunityCost: manager.includeOpportunityCost,
          );
          break;
        case 'points':
          totalSavings = calculateTotalCostDifference(
            remainingBalance: manager.remainingBalance,
            remainingTermMonths: manager.remainingTermMonths,
            currentInterestRate: manager.currentInterestRate,
            newLoanTermYears: manager.newLoanTermYears,
            newInterestRate: manager.newInterestRate,
            points: gridValue,
            financedFees: manager.financedFees,
            upfrontFees: manager.upfrontFees,
            cashOutAmount: manager.cashOutAmount,
            additionalPrincipalPayment: manager.additionalPrincipalPayment,
            investmentReturnRate: manager.investmentReturnRate,
            includeOpportunityCost: manager.includeOpportunityCost,
          );
          break;
        case 'financedFees':
          totalSavings = calculateTotalCostDifference(
            remainingBalance: manager.remainingBalance,
            remainingTermMonths: manager.remainingTermMonths,
            currentInterestRate: manager.currentInterestRate,
            newLoanTermYears: manager.newLoanTermYears,
            newInterestRate: manager.newInterestRate,
            points: manager.points,
            financedFees: gridValue,
            upfrontFees: manager.upfrontFees,
            cashOutAmount: manager.cashOutAmount,
            additionalPrincipalPayment: manager.additionalPrincipalPayment,
            investmentReturnRate: manager.investmentReturnRate,
            includeOpportunityCost: manager.includeOpportunityCost,
          );
          break;
        case 'upfrontFees':
          totalSavings = calculateTotalCostDifference(
            remainingBalance: manager.remainingBalance,
            remainingTermMonths: manager.remainingTermMonths,
            currentInterestRate: manager.currentInterestRate,
            newLoanTermYears: manager.newLoanTermYears,
            newInterestRate: manager.newInterestRate,
            points: manager.points,
            financedFees: manager.financedFees,
            upfrontFees: gridValue,
            cashOutAmount: manager.cashOutAmount,
            additionalPrincipalPayment: manager.additionalPrincipalPayment,
            investmentReturnRate: manager.investmentReturnRate,
            includeOpportunityCost: manager.includeOpportunityCost,
          );
          break;
        case 'cashOutAmount':
          totalSavings = calculateTotalCostDifference(
            remainingBalance: manager.remainingBalance,
            remainingTermMonths: manager.remainingTermMonths,
            currentInterestRate: manager.currentInterestRate,
            newLoanTermYears: manager.newLoanTermYears,
            newInterestRate: manager.newInterestRate,
            points: manager.points,
            financedFees: manager.financedFees,
            upfrontFees: manager.upfrontFees,
            cashOutAmount: gridValue,
            additionalPrincipalPayment: manager.additionalPrincipalPayment,
            investmentReturnRate: manager.investmentReturnRate,
            includeOpportunityCost: manager.includeOpportunityCost,
          );
          break;
        case 'additionalPrincipalPayment':
          totalSavings = calculateTotalCostDifference(
            remainingBalance: manager.remainingBalance,
            remainingTermMonths: manager.remainingTermMonths,
            currentInterestRate: manager.currentInterestRate,
            newLoanTermYears: manager.newLoanTermYears,
            newInterestRate: manager.newInterestRate,
            points: manager.points,
            financedFees: manager.financedFees,
            upfrontFees: manager.upfrontFees,
            cashOutAmount: manager.cashOutAmount,
            additionalPrincipalPayment: gridValue,
            investmentReturnRate: manager.investmentReturnRate,
            includeOpportunityCost: manager.includeOpportunityCost,
          );
          break;
        case 'investmentReturnRate':
          totalSavings = calculateTotalCostDifference(
            remainingBalance: manager.remainingBalance,
            remainingTermMonths: manager.remainingTermMonths,
            currentInterestRate: manager.currentInterestRate,
            newLoanTermYears: manager.newLoanTermYears,
            newInterestRate: manager.newInterestRate,
            points: manager.points,
            financedFees: manager.financedFees,
            upfrontFees: manager.upfrontFees,
            cashOutAmount: manager.cashOutAmount,
            additionalPrincipalPayment: manager.additionalPrincipalPayment,
            investmentReturnRate: gridValue,
            includeOpportunityCost: manager.includeOpportunityCost,
          );
          break;
        default:
          totalSavings = manager.calculateTotalCostDifference();
      }

      spots.add(ChartSpot(index: gridValue, value: totalSavings));
    }

    // Rescale values for display
    var rescaledValues = Vector.fromList(spots.map((i) => i.value).toList());
    final smallest = rescaledValues.min();
    final largest = rescaledValues.max();

    if (smallest != largest) {
      rescaledValues = rescaledValues.rescale();
    } else {
      rescaledValues = Vector.filled(rescaledValues.length, 0.0);
    }

    final rescaledIndex =
        Vector.fromList(spots.map((i) => i.index).toList()).rescale();

    for (int i = 0; i < spots.length; i++) {
      spots[i].value = rescaledValues[i];
      spots[i].index = rescaledIndex[i];
    }

    return ChartData(
      spots: spots,
      series: "totalSavings",
      minY: smallest,
      maxY: largest,
      minX: min,
      maxX: max,
      length: spots.length,
    );
  }

  /// Calculate month-by-month breakdown comparing current loan vs refinance
  static List<MonthlyBreakdown> calculateMonthlyBreakdown({
    required double remainingBalance,
    required int remainingTermMonths,
    required double currentInterestRate,
    required int newLoanTermYears,
    required double newInterestRate,
    required double points,
    required double financedFees,
    required double upfrontFees,
    required double cashOutAmount,
    required double additionalPrincipalPayment,
    required double investmentReturnRate,
    required bool includeOpportunityCost,
  }) {
    final List<MonthlyBreakdown> breakdown = [];

    // Calculate monthly payments
    final currentMonthlyPayment = calculateMonthlyPayment(
      principal: remainingBalance,
      annualInterestRate: currentInterestRate,
      termMonths: remainingTermMonths,
    );

    final newLoanAmount = calculateNewLoanAmount(
      remainingBalance: remainingBalance,
      cashOutAmount: cashOutAmount,
      financedFees: financedFees,
      additionalPrincipalPayment: additionalPrincipalPayment,
    );

    final newLoanTermMonths = newLoanTermYears * 12;
    final newMonthlyPayment = calculateMonthlyPayment(
      principal: newLoanAmount,
      annualInterestRate: newInterestRate,
      termMonths: newLoanTermMonths,
    );

    // Calculate upfront costs
    final upfrontCosts = calculateUpfrontCosts(
      loanAmount: newLoanAmount,
      points: points,
      upfrontFees: upfrontFees,
      additionalPrincipalPayment: additionalPrincipalPayment,
    );

    // Initialize balances
    double currentBalance = remainingBalance;
    double newBalance = newLoanAmount;
    double cumulativeSavings = -upfrontCosts +
        cashOutAmount; // Start with cash out minus upfront costs

    final currentMonthlyRate = currentInterestRate / 100 / 12;
    final newMonthlyRate = newInterestRate / 100 / 12;

    // Calculate month-by-month for the longer of the two loans
    final maxMonths = math.max(remainingTermMonths, newLoanTermMonths);

    for (int month = 1; month <= maxMonths; month++) {
      // Current loan calculations
      double currentInterestPayment = 0;
      double currentPrincipalPayment = 0;
      double currentPayment = 0;

      if (month <= remainingTermMonths && currentBalance > 0) {
        currentInterestPayment = currentBalance * currentMonthlyRate;
        currentPrincipalPayment =
            currentMonthlyPayment - currentInterestPayment;
        currentPayment = currentMonthlyPayment;
        currentBalance = math.max(0, currentBalance - currentPrincipalPayment);
      }

      // New loan calculations
      double newInterestPayment = 0;
      double newPrincipalPayment = 0;
      double newPayment = 0;

      if (month <= newLoanTermMonths && newBalance > 0) {
        newInterestPayment = newBalance * newMonthlyRate;
        newPrincipalPayment = newMonthlyPayment - newInterestPayment;
        newPayment = newMonthlyPayment;
        newBalance = math.max(0, newBalance - newPrincipalPayment);
      }

      // Calculate savings for this month
      final monthlySavings = currentPayment - newPayment;
      cumulativeSavings += monthlySavings;

      // Add opportunity cost if enabled (monthly impact)
      if (includeOpportunityCost && upfrontCosts > 0) {
        final monthlyInvestmentRate = investmentReturnRate / 100 / 12;
        final opportunityCostThisMonth = upfrontCosts *
            monthlyInvestmentRate *
            math.pow(1 + monthlyInvestmentRate, month - 1);
        cumulativeSavings -= opportunityCostThisMonth;
      }

      breakdown.add(MonthlyBreakdown(
        month: month,
        currentLoanBalance: currentBalance,
        currentLoanPayment: currentPayment,
        currentLoanInterest: currentInterestPayment,
        currentLoanPrincipal: currentPrincipalPayment,
        newLoanBalance: newBalance,
        newLoanPayment: newPayment,
        newLoanInterest: newInterestPayment,
        newLoanPrincipal: newPrincipalPayment,
        monthlySavings: monthlySavings,
        cumulativeSavings: cumulativeSavings,
      ));
    }

    return breakdown;
  }

  /// Calculate month-by-month breakdown asynchronously with chunking to avoid UI freeze
  static Future<List<MonthlyBreakdown>> calculateMonthlyBreakdownAsync({
    required double remainingBalance,
    required int remainingTermMonths,
    required double currentInterestRate,
    required int newLoanTermYears,
    required double newInterestRate,
    required double points,
    required double financedFees,
    required double upfrontFees,
    required double cashOutAmount,
    required double additionalPrincipalPayment,
    required double investmentReturnRate,
    required bool includeOpportunityCost,
  }) async {
    final List<MonthlyBreakdown> breakdown = [];

    // Calculate monthly payments
    final currentMonthlyPayment = calculateMonthlyPayment(
      principal: remainingBalance,
      annualInterestRate: currentInterestRate,
      termMonths: remainingTermMonths,
    );

    final newLoanAmount = calculateNewLoanAmount(
      remainingBalance: remainingBalance,
      cashOutAmount: cashOutAmount,
      financedFees: financedFees,
      additionalPrincipalPayment: additionalPrincipalPayment,
    );

    final newLoanTermMonths = newLoanTermYears * 12;
    final newMonthlyPayment = calculateMonthlyPayment(
      principal: newLoanAmount,
      annualInterestRate: newInterestRate,
      termMonths: newLoanTermMonths,
    );

    // Calculate upfront costs
    final upfrontCosts = calculateUpfrontCosts(
      loanAmount: newLoanAmount,
      points: points,
      upfrontFees: upfrontFees,
      additionalPrincipalPayment: additionalPrincipalPayment,
    );

    // Initialize balances
    double currentBalance = remainingBalance;
    double newBalance = newLoanAmount;
    double cumulativeSavings = -upfrontCosts + cashOutAmount;

    final currentMonthlyRate = currentInterestRate / 100 / 12;
    final newMonthlyRate = newInterestRate / 100 / 12;

    final maxMonths = math.max(remainingTermMonths, newLoanTermMonths);

    // Process in chunks of 12 months (1 year)
    for (int month = 1; month <= maxMonths; month++) {
      // Yield to event loop every 12 months to keep UI responsive
      if (month % 12 == 0) {
        await Future.delayed(Duration.zero);
      }

      // Current loan calculations
      double currentInterestPayment = 0;
      double currentPrincipalPayment = 0;
      double currentPayment = 0;

      if (month <= remainingTermMonths && currentBalance > 0) {
        currentInterestPayment = currentBalance * currentMonthlyRate;
        currentPrincipalPayment =
            currentMonthlyPayment - currentInterestPayment;
        currentPayment = currentMonthlyPayment;
        currentBalance = math.max(0, currentBalance - currentPrincipalPayment);
      }

      // New loan calculations
      double newInterestPayment = 0;
      double newPrincipalPayment = 0;
      double newPayment = 0;

      if (month <= newLoanTermMonths && newBalance > 0) {
        newInterestPayment = newBalance * newMonthlyRate;
        newPrincipalPayment = newMonthlyPayment - newInterestPayment;
        newPayment = newMonthlyPayment;
        newBalance = math.max(0, newBalance - newPrincipalPayment);
      }

      // Calculate savings for this month
      final monthlySavings = currentPayment - newPayment;
      cumulativeSavings += monthlySavings;

      // Add opportunity cost if enabled
      if (includeOpportunityCost && upfrontCosts > 0) {
        final monthlyInvestmentRate = investmentReturnRate / 100 / 12;
        final opportunityCostThisMonth = upfrontCosts *
            monthlyInvestmentRate *
            math.pow(1 + monthlyInvestmentRate, month - 1);
        cumulativeSavings -= opportunityCostThisMonth;
      }

      breakdown.add(MonthlyBreakdown(
        month: month,
        currentLoanBalance: currentBalance,
        currentLoanPayment: currentPayment,
        currentLoanInterest: currentInterestPayment,
        currentLoanPrincipal: currentPrincipalPayment,
        newLoanBalance: newBalance,
        newLoanPayment: newPayment,
        newLoanInterest: newInterestPayment,
        newLoanPrincipal: newPrincipalPayment,
        monthlySavings: monthlySavings,
        cumulativeSavings: cumulativeSavings,
      ));
    }

    return breakdown;
  }
}
