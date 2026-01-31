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
  final bool isSaleRow; // Indicates if this is the final home sale row

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
    this.isSaleRow = false,
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

  // Calculate the remaining balance on a loan after making payments for a given number of months
  static double calculateBalanceAfterPayments({
    required double principal,
    required double annualInterestRate,
    required int termMonths,
    required int monthsPaid,
  }) {
    if (monthsPaid >= termMonths) {
      return 0.0;
    }

    if (monthsPaid <= 0) {
      return principal;
    }

    final monthlyRate = annualInterestRate / 100 / 12;

    if (monthlyRate == 0) {
      // Simple linear amortization if no interest
      final monthlyPrincipal = principal / termMonths;
      return principal - (monthlyPrincipal * monthsPaid);
    }

    final monthlyPayment = calculateMonthlyPayment(
      principal: principal,
      annualInterestRate: annualInterestRate,
      termMonths: termMonths,
    );

    // Calculate remaining balance after monthsPaid
    // Formula: Balance = P * (1 + r)^n - M * [(1 + r)^n - 1] / r
    final onePlusR = 1 + monthlyRate;
    final balance = principal * math.pow(onePlusR, monthsPaid) -
        monthlyPayment * ((math.pow(onePlusR, monthsPaid) - 1) / monthlyRate);

    return math.max(0, balance);
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
    required int monthsUntilSale,
  }) {
    final numPayments = newLoanTermYears * 12;

    // Calculate new loan amount
    final newLoanAmount = calculateNewLoanAmount(
      remainingBalance: remainingBalance,
      cashOutAmount: cashOutAmount,
      financedFees: financedFees,
      additionalPrincipalPayment: additionalPrincipalPayment,
    );

    // Calculate upfront costs
    final upfrontCosts = calculateUpfrontCosts(
      loanAmount: newLoanAmount,
      points: points,
      upfrontFees: upfrontFees,
      additionalPrincipalPayment: additionalPrincipalPayment,
    );

    // Determine if we're selling before both loans would naturally end
    final maxMonths = math.max(remainingTermMonths, numPayments);
    final isSelling = monthsUntilSale > 0 && monthsUntilSale <= maxMonths;

    // Determine the evaluation period (either sale date or end of loan term)
    final currentEvalMonths =
        isSelling && monthsUntilSale <= remainingTermMonths
            ? monthsUntilSale
            : remainingTermMonths;
    final newEvalMonths = isSelling && monthsUntilSale <= numPayments
        ? monthsUntilSale
        : numPayments;

    // Use the longer of the two for opportunity cost calculation
    final opportunityCostMonths = math.max(currentEvalMonths, newEvalMonths);

    // Current loan: calculate payments and remaining balance
    final currentMonthlyPayment = calculateMonthlyPayment(
      principal: remainingBalance,
      annualInterestRate: currentInterestRate,
      termMonths: remainingTermMonths,
    );
    final currentBalanceAtEnd = calculateBalanceAfterPayments(
      principal: remainingBalance,
      annualInterestRate: currentInterestRate,
      termMonths: remainingTermMonths,
      monthsPaid: currentEvalMonths,
    );
    final currentTotalPaid = currentMonthlyPayment * currentEvalMonths;

    // New loan: calculate payments and remaining balance
    final newMonthlyPayment = calculateMonthlyPayment(
      principal: newLoanAmount,
      annualInterestRate: newInterestRate,
      termMonths: numPayments,
    );
    final newBalanceAtEnd = calculateBalanceAfterPayments(
      principal: newLoanAmount,
      annualInterestRate: newInterestRate,
      termMonths: numPayments,
      monthsPaid: newEvalMonths,
    );
    final newTotalPaid = newMonthlyPayment * newEvalMonths;

    // Calculate opportunity cost
    final opportunityCost = includeOpportunityCost
        ? calculateOpportunityCost(
            upfrontCosts: upfrontCosts,
            investmentReturnRate: investmentReturnRate,
            termMonths: opportunityCostMonths,
          )
        : 0.0;

    // When selling, the home value cancels out in the comparison:
    // (HomeValue - CurrentBalance) vs (HomeValue - NewBalance)
    // So we just need to compare the remaining balances directly
    // Total cost = payments made + remaining balance at end
    final currentTotalCost = currentTotalPaid + currentBalanceAtEnd;
    final newTotalCost = newTotalPaid +
        upfrontCosts +
        opportunityCost -
        cashOutAmount +
        newBalanceAtEnd;

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
            monthsUntilSale: manager.monthsUntilSale,
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
            monthsUntilSale: manager.monthsUntilSale,
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
            monthsUntilSale: manager.monthsUntilSale,
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
            monthsUntilSale: manager.monthsUntilSale,
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
            monthsUntilSale: manager.monthsUntilSale,
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
            monthsUntilSale: manager.monthsUntilSale,
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
            monthsUntilSale: manager.monthsUntilSale,
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
            monthsUntilSale: manager.monthsUntilSale,
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
            monthsUntilSale: manager.monthsUntilSale,
          );
          break;
        case 'monthsUntilSale':
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
            investmentReturnRate: manager.investmentReturnRate,
            includeOpportunityCost: manager.includeOpportunityCost,
            monthsUntilSale: gridValue.round(),
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
    required int monthsUntilSale,
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
    // Track cumulative payment savings separately from opportunity cost
    double cumulativePaymentSavings = 0;

    final currentMonthlyRate = currentInterestRate / 100 / 12;
    final newMonthlyRate = newInterestRate / 100 / 12;

    final maxMonths = math.max(remainingTermMonths, newLoanTermMonths);
    final isSelling = monthsUntilSale > 0 && monthsUntilSale <= maxMonths;
    final lastMonth = isSelling ? monthsUntilSale : maxMonths;

    // Process in chunks of 12 months (1 year)
    for (int month = 1; month <= lastMonth; month++) {
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
      double monthlySavings = currentPayment - newPayment;
      cumulativePaymentSavings += monthlySavings;

      // Calculate opportunity cost at this point in time (matches calculateTotalCostDifference)
      final opportunityCost = includeOpportunityCost
          ? calculateOpportunityCost(
              upfrontCosts: upfrontCosts,
              investmentReturnRate: investmentReturnRate,
              termMonths: month,
            )
          : 0.0;

      // Cumulative savings = payment savings - upfront costs + cash out - opportunity cost
      double cumulativeSavings = cumulativePaymentSavings -
          upfrontCosts +
          cashOutAmount -
          opportunityCost;

      // Check if this is the sale month - combine payment with sale proceeds
      final isSaleMonth = isSelling && month == monthsUntilSale;

      if (isSaleMonth) {
        // When selling, home value cancels out in the comparison:
        // currentNetProceeds = homeValue - currentBalance
        // newNetProceeds = homeValue - newBalance
        // proceedsDifference = newNetProceeds - currentNetProceeds = currentBalance - newBalance
        final balanceDifference = currentBalance - newBalance;

        // Add balance difference to cumulative savings (positive if new loan has lower balance)
        cumulativeSavings += balanceDifference;

        // Show payoff amounts in the payment columns
        final currentTotalPayment = currentPayment + currentBalance;
        final newTotalPayment = newPayment + newBalance;

        breakdown.add(MonthlyBreakdown(
          month: month,
          currentLoanBalance: 0, // Balance is 0 after sale
          currentLoanPayment: currentTotalPayment,
          currentLoanInterest: currentInterestPayment,
          currentLoanPrincipal:
              currentPrincipalPayment + currentBalance, // Includes payoff
          newLoanBalance: 0, // Balance is 0 after sale
          newLoanPayment: newTotalPayment,
          newLoanInterest: newInterestPayment,
          newLoanPrincipal: newPrincipalPayment + newBalance, // Includes payoff
          monthlySavings: monthlySavings + balanceDifference,
          cumulativeSavings: cumulativeSavings,
          isSaleRow: true,
        ));
      } else {
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
    }

    return breakdown;
  }
}
