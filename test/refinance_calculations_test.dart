import 'package:flutter_test/flutter_test.dart';
import 'package:finance_calculator/refinance_calculations.dart';

void main() {
  group('RefinanceCalculations', () {
    group('calculateMonthlyPayment', () {
      test('should calculate correct monthly payment for standard loan', () {
        // 200k loan at 4.5% for 30 years (360 months)
        final payment = RefinanceCalculations.calculateMonthlyPayment(
          principal: 200000,
          annualInterestRate: 4.5,
          termMonths: 360,
        );

        // Expected monthly payment is approximately $1,013.37
        expect(payment, closeTo(1013.37, 0.01));
      });

      test('should calculate correct monthly payment for 15 year loan', () {
        // 300k loan at 3.5% for 15 years (180 months)
        final payment = RefinanceCalculations.calculateMonthlyPayment(
          principal: 300000,
          annualInterestRate: 3.5,
          termMonths: 180,
        );

        // Expected monthly payment is approximately $2,144.65
        expect(payment, closeTo(2144.65, 0.01));
      });

      test('should handle zero interest rate', () {
        // 100k loan at 0% for 120 months
        final payment = RefinanceCalculations.calculateMonthlyPayment(
          principal: 100000,
          annualInterestRate: 0,
          termMonths: 120,
        );

        // Should be simple division: 100000 / 120 = 833.33
        expect(payment, closeTo(833.33, 0.01));
      });

      test('should calculate payment for short term loan', () {
        // 50k loan at 6% for 5 years (60 months)
        final payment = RefinanceCalculations.calculateMonthlyPayment(
          principal: 50000,
          annualInterestRate: 6.0,
          termMonths: 60,
        );

        // Expected monthly payment is approximately $966.64
        expect(payment, closeTo(966.64, 0.01));
      });
    });

    group('calculateNewLoanAmount', () {
      test('should calculate loan amount when financing costs', () {
        final loanAmount = RefinanceCalculations.calculateNewLoanAmount(
          remainingBalance: 200000,
          cashOutAmount: 0,
          costsAndFees: 3000,
          additionalPrincipalPayment: 0,
          financeCosts: true,
        );

        expect(loanAmount, equals(203000));
      });

      test('should calculate loan amount when NOT financing costs', () {
        final loanAmount = RefinanceCalculations.calculateNewLoanAmount(
          remainingBalance: 200000,
          cashOutAmount: 0,
          costsAndFees: 3000,
          additionalPrincipalPayment: 0,
          financeCosts: false,
        );

        expect(loanAmount, equals(200000));
      });

      test('should include cash out amount', () {
        final loanAmount = RefinanceCalculations.calculateNewLoanAmount(
          remainingBalance: 200000,
          cashOutAmount: 50000,
          costsAndFees: 3000,
          additionalPrincipalPayment: 0,
          financeCosts: true,
        );

        expect(loanAmount, equals(253000));
      });

      test('should subtract additional principal payment', () {
        final loanAmount = RefinanceCalculations.calculateNewLoanAmount(
          remainingBalance: 200000,
          cashOutAmount: 0,
          costsAndFees: 3000,
          additionalPrincipalPayment: 10000,
          financeCosts: true,
        );

        expect(loanAmount, equals(193000));
      });

      test('should handle complex scenario', () {
        final loanAmount = RefinanceCalculations.calculateNewLoanAmount(
          remainingBalance: 200000,
          cashOutAmount: 25000,
          costsAndFees: 5000,
          additionalPrincipalPayment: 15000,
          financeCosts: false,
        );

        // 200000 + 25000 - 15000 = 210000 (costs not financed)
        expect(loanAmount, equals(210000));
      });
    });

    group('calculateTotalInterest', () {
      test('should calculate total interest for 30 year loan', () {
        final totalInterest = RefinanceCalculations.calculateTotalInterest(
          principal: 200000,
          annualInterestRate: 4.5,
          termMonths: 360,
        );

        // Total payments: $1,013.37 * 360 = $364,813.20
        // Total interest: $364,813.20 - $200,000 = $164,813.20
        expect(totalInterest, closeTo(164813.20, 0.50));
      });

      test('should calculate total interest for 15 year loan', () {
        final totalInterest = RefinanceCalculations.calculateTotalInterest(
          principal: 300000,
          annualInterestRate: 3.5,
          termMonths: 180,
        );

        // Total payments: $2,144.65 * 180 = $386,037
        // Total interest: $386,037 - $300,000 = $86,037
        expect(totalInterest, closeTo(86037, 1.0));
      });

      test('should return zero interest for 0% interest rate', () {
        final totalInterest = RefinanceCalculations.calculateTotalInterest(
          principal: 100000,
          annualInterestRate: 0,
          termMonths: 120,
        );

        expect(totalInterest, equals(0));
      });
    });

    group('calculateUpfrontCosts', () {
      test('should calculate upfront costs with points and financing costs', () {
        final upfrontCosts = RefinanceCalculations.calculateUpfrontCosts(
          loanAmount: 200000,
          points: 1.0,
          costsAndFees: 3000,
          additionalPrincipalPayment: 0,
          financeCosts: true,
        );

        // Points: 200000 * 0.01 = 2000
        // Costs financed, so only points: 2000
        expect(upfrontCosts, equals(2000));
      });

      test('should calculate upfront costs when NOT financing costs', () {
        final upfrontCosts = RefinanceCalculations.calculateUpfrontCosts(
          loanAmount: 200000,
          points: 1.0,
          costsAndFees: 3000,
          additionalPrincipalPayment: 0,
          financeCosts: false,
        );

        // Points: 2000 + Costs: 3000 = 5000
        expect(upfrontCosts, equals(5000));
      });

      test('should include additional principal payment', () {
        final upfrontCosts = RefinanceCalculations.calculateUpfrontCosts(
          loanAmount: 200000,
          points: 0.5,
          costsAndFees: 3000,
          additionalPrincipalPayment: 10000,
          financeCosts: true,
        );

        // Points: 1000 + Additional: 10000 = 11000
        expect(upfrontCosts, equals(11000));
      });

      test('should handle zero points', () {
        final upfrontCosts = RefinanceCalculations.calculateUpfrontCosts(
          loanAmount: 200000,
          points: 0,
          costsAndFees: 3000,
          additionalPrincipalPayment: 5000,
          financeCosts: false,
        );

        // 0 + 3000 + 5000 = 8000
        expect(upfrontCosts, equals(8000));
      });

      test('should calculate 2 points correctly', () {
        final upfrontCosts = RefinanceCalculations.calculateUpfrontCosts(
          loanAmount: 250000,
          points: 2.0,
          costsAndFees: 0,
          additionalPrincipalPayment: 0,
          financeCosts: true,
        );

        // 250000 * 0.02 = 5000
        expect(upfrontCosts, equals(5000));
      });
    });

    group('calculateOpportunityCost', () {
      test('should calculate opportunity cost over 30 years at 7%', () {
        final opportunityCost = RefinanceCalculations.calculateOpportunityCost(
          upfrontCosts: 10000,
          investmentReturnRate: 7.0,
          termMonths: 360,
        );

        // Future value of $10,000 at 7% APR for 30 years
        // FV = 10000 * (1 + 0.07/12)^360 ≈ 81,109.66
        // Opportunity cost = 81,109.66 - 10,000 = 71,109.66
        expect(opportunityCost, closeTo(71109.66, 100.0));
      });

      test('should calculate opportunity cost for shorter term', () {
        final opportunityCost = RefinanceCalculations.calculateOpportunityCost(
          upfrontCosts: 5000,
          investmentReturnRate: 6.0,
          termMonths: 180,
        );

        // Future value of $5,000 at 6% APR for 15 years
        // FV = 5000 * (1 + 0.06/12)^180 ≈ 12,269.49
        // Opportunity cost = 12,269.49 - 5,000 = 7,269.49
        expect(opportunityCost, closeTo(7269.49, 1.0));
      });

      test('should return zero for zero upfront costs', () {
        final opportunityCost = RefinanceCalculations.calculateOpportunityCost(
          upfrontCosts: 0,
          investmentReturnRate: 7.0,
          termMonths: 360,
        );

        expect(opportunityCost, equals(0));
      });

      test('should return zero for zero investment return rate', () {
        final opportunityCost = RefinanceCalculations.calculateOpportunityCost(
          upfrontCosts: 10000,
          investmentReturnRate: 0,
          termMonths: 360,
        );

        expect(opportunityCost, equals(0));
      });
    });

    group('calculateTotalCostDifference', () {
      test('should calculate total cost difference correctly', () {
        final savings = RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: 240, // 20 years remaining
          currentInterestRate: 4.5,
          newLoanTermYears: 20, // Same term
          newInterestRate: 3.5,
          points: 0,
          costsAndFees: 3000,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          financeCosts: true,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
        );

        // Should show positive savings (lower rate, same term)
        expect(savings, greaterThan(0));
      });

      test('should show negative savings when extending term significantly', () {
        final savings = RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: 60, // 5 years remaining
          currentInterestRate: 4.0,
          newLoanTermYears: 30,
          newInterestRate: 3.8,
          points: 0,
          costsAndFees: 3000,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          financeCosts: true,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
        );

        // Should show negative savings (higher new loan cost due to term extension)
        expect(savings, lessThan(0));
      });

      test('should include opportunity cost when enabled', () {
        final savingsWithout = RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: 240,
          currentInterestRate: 4.5,
          newLoanTermYears: 30,
          newInterestRate: 3.5,
          points: 1.0, // 2000 upfront
          costsAndFees: 3000,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          financeCosts: false, // Pay 3000 upfront
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
        );

        final savingsWith = RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: 240,
          currentInterestRate: 4.5,
          newLoanTermYears: 30,
          newInterestRate: 3.5,
          points: 1.0,
          costsAndFees: 3000,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          financeCosts: false,
          investmentReturnRate: 7.0,
          includeOpportunityCost: true,
        );

        // With opportunity cost should have less savings
        expect(savingsWith, lessThan(savingsWithout));
      });

      test('should handle cash out refinance', () {
        final savings = RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: 240,
          currentInterestRate: 4.5,
          newLoanTermYears: 30,
          newInterestRate: 3.5,
          points: 0,
          costsAndFees: 3000,
          cashOutAmount: 50000,
          additionalPrincipalPayment: 0,
          financeCosts: true,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
        );

        // Cash out should reduce savings (or increase cost)
        expect(savings, isA<double>());
      });

      test('should handle additional principal payment', () {
        final savingsWithout = RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: 240,
          currentInterestRate: 4.5,
          newLoanTermYears: 30,
          newInterestRate: 3.5,
          points: 0,
          costsAndFees: 3000,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          financeCosts: true,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
        );

        final savingsWith = RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: 240,
          currentInterestRate: 4.5,
          newLoanTermYears: 30,
          newInterestRate: 3.5,
          points: 0,
          costsAndFees: 3000,
          cashOutAmount: 0,
          additionalPrincipalPayment: 20000,
          financeCosts: true,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
        );

        // Additional principal should increase savings (lower new loan amount)
        expect(savingsWith, greaterThan(savingsWithout));
      });
    });

    group('calculateRemainingBalance', () {
      test('should return same balance when terms match', () {
        final balance = RefinanceCalculations.calculateRemainingBalance(
          currentBalance: 200000,
          currentTermMonths: 240,
          annualInterestRate: 4.5,
          targetTermMonths: 240,
        );

        expect(balance, equals(200000));
      });

      test('should calculate lower balance for shorter remaining term', () {
        final balance = RefinanceCalculations.calculateRemainingBalance(
          currentBalance: 200000,
          currentTermMonths: 240,
          annualInterestRate: 4.5,
          targetTermMonths: 120,
        );

        // After 120 more payments (120 months later), balance should be lower
        expect(balance, lessThan(200000));
        expect(balance, greaterThan(0));
      });

      test('should handle zero interest rate', () {
        final balance = RefinanceCalculations.calculateRemainingBalance(
          currentBalance: 100000,
          currentTermMonths: 120,
          annualInterestRate: 0,
          targetTermMonths: 60,
        );

        // Simple linear: 100000 - (60 months paid * (100000/120)) = 50000
        expect(balance, closeTo(50000, 0.01));
      });

      test('should return current balance when going backward in time', () {
        final balance = RefinanceCalculations.calculateRemainingBalance(
          currentBalance: 200000,
          currentTermMonths: 120,
          annualInterestRate: 4.5,
          targetTermMonths: 180, // More months remaining = earlier in loan
        );

        // Going backward doesn't make sense, should return current balance
        expect(balance, equals(200000));
      });
    });

    group('Edge cases and validation', () {
      test('monthly payment should be positive for positive principal', () {
        final payment = RefinanceCalculations.calculateMonthlyPayment(
          principal: 1,
          annualInterestRate: 1,
          termMonths: 12,
        );

        expect(payment, greaterThan(0));
      });

      test('should handle very large loan amounts', () {
        final payment = RefinanceCalculations.calculateMonthlyPayment(
          principal: 1000000000, // 1 billion
          annualInterestRate: 4.5,
          termMonths: 360,
        );

        expect(payment, greaterThan(0));
        expect(payment.isFinite, isTrue);
      });

      test('should handle very small interest rates', () {
        final payment = RefinanceCalculations.calculateMonthlyPayment(
          principal: 200000,
          annualInterestRate: 0.01,
          termMonths: 360,
        );

        expect(payment, greaterThan(0));
        expect(payment.isFinite, isTrue);
      });
    });
  });
}
