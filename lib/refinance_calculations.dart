import 'dart:math' as math;
import 'package:ml_linalg/linalg.dart';
import 'chart.dart';
import 'refinance_manager.dart';
import 'utils.dart';

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
    required double costsAndFees,
    required double additionalPrincipalPayment,
    required bool financeCosts,
  }) {
    double loanAmount = remainingBalance + cashOutAmount;
    if (financeCosts) {
      loanAmount += costsAndFees;
    }
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
    required double remainingBalance,
    required double points,
    required double costsAndFees,
    required double additionalPrincipalPayment,
    required bool financeCosts,
  }) {
    final pointsCost = remainingBalance * (points / 100);
    double upfrontCosts = pointsCost;
    if (!financeCosts) {
      upfrontCosts += costsAndFees;
    }
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
    required double costsAndFees,
    required double cashOutAmount,
    required double additionalPrincipalPayment,
    required bool financeCosts,
    required double investmentReturnRate,
    required bool includeOpportunityCost,
  }) {
    final numPayments = newLoanTermYears * 12;
    
    // Calculate new loan amount using static helper
    final newLoanAmount = calculateNewLoanAmount(
      remainingBalance: remainingBalance,
      cashOutAmount: cashOutAmount,
      costsAndFees: costsAndFees,
      additionalPrincipalPayment: additionalPrincipalPayment,
      financeCosts: financeCosts,
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
      remainingBalance: remainingBalance,
      points: points,
      costsAndFees: costsAndFees,
      additionalPrincipalPayment: additionalPrincipalPayment,
      financeCosts: financeCosts,
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
    final newTotalCost = totalInterestNew + newLoanAmount + upfrontCosts + opportunityCost - cashOutAmount;
    
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
      return currentBalance - (monthsPassed * (currentBalance / currentTermMonths));
    }
    
    // Calculate the monthly payment based on current situation
    final monthlyPayment = calculateMonthlyPayment(
      principal: currentBalance,
      annualInterestRate: annualInterestRate,
      termMonths: currentTermMonths,
    );
    
    // Calculate remaining balance at target term using standard formula
    // Remaining balance = P * [(1 + r)^n - (1 + r)^p] / [(1 + r)^n - 1]
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
    final numerator = currentBalance * math.pow(onePlusR, currentTermMonths) - 
                     monthlyPayment * ((math.pow(onePlusR, monthsPassed) - 1) / monthlyRate);
    final denominator = math.pow(onePlusR, currentTermMonths - monthsPassed);
    
    return numerator / denominator;
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
            costsAndFees: manager.costsAndFees,
            cashOutAmount: manager.cashOutAmount,
            additionalPrincipalPayment: manager.additionalPrincipalPayment,
            financeCosts: manager.financeCosts,
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
            costsAndFees: manager.costsAndFees,
            cashOutAmount: manager.cashOutAmount,
            additionalPrincipalPayment: manager.additionalPrincipalPayment,
            financeCosts: manager.financeCosts,
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
            costsAndFees: manager.costsAndFees,
            cashOutAmount: manager.cashOutAmount,
            additionalPrincipalPayment: manager.additionalPrincipalPayment,
            financeCosts: manager.financeCosts,
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
            costsAndFees: manager.costsAndFees,
            cashOutAmount: manager.cashOutAmount,
            additionalPrincipalPayment: manager.additionalPrincipalPayment,
            financeCosts: manager.financeCosts,
            investmentReturnRate: manager.investmentReturnRate,
            includeOpportunityCost: manager.includeOpportunityCost,
          );
          break;
        case 'costsAndFees':
          totalSavings = calculateTotalCostDifference(
            remainingBalance: manager.remainingBalance,
            remainingTermMonths: manager.remainingTermMonths,
            currentInterestRate: manager.currentInterestRate,
            newLoanTermYears: manager.newLoanTermYears,
            newInterestRate: manager.newInterestRate,
            points: manager.points,
            costsAndFees: gridValue,
            cashOutAmount: manager.cashOutAmount,
            additionalPrincipalPayment: manager.additionalPrincipalPayment,
            financeCosts: manager.financeCosts,
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
            costsAndFees: manager.costsAndFees,
            cashOutAmount: gridValue,
            additionalPrincipalPayment: manager.additionalPrincipalPayment,
            financeCosts: manager.financeCosts,
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
            costsAndFees: manager.costsAndFees,
            cashOutAmount: manager.cashOutAmount,
            additionalPrincipalPayment: gridValue,
            financeCosts: manager.financeCosts,
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
            costsAndFees: manager.costsAndFees,
            cashOutAmount: manager.cashOutAmount,
            additionalPrincipalPayment: manager.additionalPrincipalPayment,
            financeCosts: manager.financeCosts,
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
    
    final rescaledIndex = Vector.fromList(spots.map((i) => i.index).toList()).rescale();
    
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
}
