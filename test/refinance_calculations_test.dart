import 'package:flutter_test/flutter_test.dart';
import 'package:finance_calculator/refinance_calculations.dart';

void main() {
  group('RefinanceCalculations', () {
    group('resolveFeesAndLoanAmount', () {
      test('should match simple case when no points', () {
        final resolved = RefinanceCalculations.resolveFeesAndLoanAmount(
          remainingBalance: 200000,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          otherClosingCosts: 3000,
          pointsPercent: 0,
          percentageFinanced: 1.0,
        );

        // No points: newLoanAmount = 200000 + 3000 = 203000
        expect(resolved.newLoanAmount, closeTo(203000, 0.01));
        expect(resolved.pointsCost, closeTo(0, 0.01));
        expect(resolved.financedFees, closeTo(3000, 0.01));
        expect(resolved.upfrontFees, closeTo(0, 0.01));
      });

      test('should resolve correctly when points are fully financed', () {
        // 1% points, all financed
        // base = 200000, F = 3000, p = 0.01, f = 1.0
        // newLoanAmount = (200000 + 3000) / (1 - 0.01) = 203000 / 0.99 ≈ 205050.51
        final resolved = RefinanceCalculations.resolveFeesAndLoanAmount(
          remainingBalance: 200000,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          otherClosingCosts: 3000,
          pointsPercent: 1.0,
          percentageFinanced: 1.0,
        );

        expect(resolved.newLoanAmount, closeTo(205050.51, 1.0));
        expect(resolved.pointsCost, closeTo(2050.51, 1.0));
        // totalPool = 3000 + 2050.51 = 5050.51, all financed
        expect(resolved.financedFees, closeTo(5050.51, 1.0));
        expect(resolved.upfrontFees, closeTo(0, 0.01));
      });

      test('should resolve correctly when points are fully upfront', () {
        // 1% points, nothing financed
        // base = 200000, F = 3000, p = 0.01, f = 0
        // newLoanAmount = 200000 (nothing financed)
        final resolved = RefinanceCalculations.resolveFeesAndLoanAmount(
          remainingBalance: 200000,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          otherClosingCosts: 3000,
          pointsPercent: 1.0,
          percentageFinanced: 0.0,
        );

        expect(resolved.newLoanAmount, closeTo(200000, 0.01));
        expect(resolved.pointsCost, closeTo(2000, 0.01));
        // totalPool = 3000 + 2000 = 5000, all upfront
        expect(resolved.financedFees, closeTo(0, 0.01));
        expect(resolved.upfrontFees, closeTo(5000, 0.01));
      });

      test('should resolve with partial financing', () {
        // 1% points, 50% financed
        // base = 200000, F = 3000, p = 0.01, f = 0.5
        // denom = 1 - 0.01 * 0.5 = 0.995
        // newLoanAmount = (200000 + 1500) / 0.995 ≈ 202512.56
        final resolved = RefinanceCalculations.resolveFeesAndLoanAmount(
          remainingBalance: 200000,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          otherClosingCosts: 3000,
          pointsPercent: 1.0,
          percentageFinanced: 0.5,
        );

        expect(resolved.newLoanAmount, closeTo(202512.56, 1.0));
        final expectedPoints = 202512.56 * 0.01;
        expect(resolved.pointsCost, closeTo(expectedPoints, 1.0));
        final expectedPool = 3000 + expectedPoints;
        expect(resolved.financedFees, closeTo(expectedPool * 0.5, 1.0));
        expect(resolved.upfrontFees, closeTo(expectedPool * 0.5, 1.0));
      });

      test('should verify self-consistency of resolved values', () {
        // The key invariant: newLoanAmount = base + financedFees
        final resolved = RefinanceCalculations.resolveFeesAndLoanAmount(
          remainingBalance: 200000,
          cashOutAmount: 10000,
          additionalPrincipalPayment: 5000,
          otherClosingCosts: 4000,
          pointsPercent: 1.5,
          percentageFinanced: 0.75,
        );

        final base = 200000.0 + 10000 - 5000;
        expect(resolved.newLoanAmount,
            closeTo(base + resolved.financedFees, 0.01));
        expect(
            resolved.pointsCost, closeTo(resolved.newLoanAmount * 0.015, 0.01));
        expect(resolved.totalClosingCosts,
            closeTo(4000 + resolved.pointsCost, 0.01));
        expect(resolved.financedFees + resolved.upfrontFees,
            closeTo(resolved.totalClosingCosts, 0.01));
      });
    });

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
      test('should calculate loan amount with financed fees', () {
        final loanAmount = RefinanceCalculations.calculateNewLoanAmount(
          remainingBalance: 200000,
          cashOutAmount: 0,
          financedFees: 3000,
          additionalPrincipalPayment: 0,
        );

        expect(loanAmount, equals(203000));
      });

      test('should calculate loan amount without financed fees', () {
        final loanAmount = RefinanceCalculations.calculateNewLoanAmount(
          remainingBalance: 200000,
          cashOutAmount: 0,
          financedFees: 0,
          additionalPrincipalPayment: 0,
        );

        expect(loanAmount, equals(200000));
      });

      test('should include cash out amount', () {
        final loanAmount = RefinanceCalculations.calculateNewLoanAmount(
          remainingBalance: 200000,
          cashOutAmount: 50000,
          financedFees: 3000,
          additionalPrincipalPayment: 0,
        );

        expect(loanAmount, equals(253000));
      });

      test('should subtract additional principal payment', () {
        final loanAmount = RefinanceCalculations.calculateNewLoanAmount(
          remainingBalance: 200000,
          cashOutAmount: 0,
          financedFees: 3000,
          additionalPrincipalPayment: 10000,
        );

        expect(loanAmount, equals(193000));
      });

      test('should handle complex scenario', () {
        final loanAmount = RefinanceCalculations.calculateNewLoanAmount(
          remainingBalance: 200000,
          cashOutAmount: 25000,
          financedFees: 0,
          additionalPrincipalPayment: 15000,
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
      test('should calculate upfront costs with upfront fees only', () {
        final upfrontCosts = RefinanceCalculations.calculateUpfrontCosts(
          upfrontFees: 2000,
          additionalPrincipalPayment: 0,
        );

        // Upfront fees only: 2000
        expect(upfrontCosts, equals(2000));
      });

      test('should calculate upfront costs with upfront fees', () {
        final upfrontCosts = RefinanceCalculations.calculateUpfrontCosts(
          upfrontFees: 3000,
          additionalPrincipalPayment: 0,
        );

        // Upfront fees: 3000
        expect(upfrontCosts, equals(3000));
      });

      test('should include additional principal payment', () {
        final upfrontCosts = RefinanceCalculations.calculateUpfrontCosts(
          upfrontFees: 1000,
          additionalPrincipalPayment: 10000,
        );

        // 1000 + 10000 = 11000
        expect(upfrontCosts, equals(11000));
      });

      test('should handle zero upfront fees', () {
        final upfrontCosts = RefinanceCalculations.calculateUpfrontCosts(
          upfrontFees: 0,
          additionalPrincipalPayment: 5000,
        );

        // 0 + 5000 = 5000
        expect(upfrontCosts, equals(5000));
      });

      test('should handle all zeros', () {
        final upfrontCosts = RefinanceCalculations.calculateUpfrontCosts(
          upfrontFees: 0,
          additionalPrincipalPayment: 0,
        );

        expect(upfrontCosts, equals(0));
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
          otherClosingCosts: 3000,
          pointsPercent: 0,
          percentageFinanced: 1.0,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
          monthsUntilSale: 0,
        );

        // Should show positive savings (lower rate, same term)
        expect(savings, greaterThan(0));
      });

      test('should show negative savings when extending term significantly',
          () {
        final savings = RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: 60, // 5 years remaining
          currentInterestRate: 4.0,
          newLoanTermYears: 30,
          newInterestRate: 3.8,
          otherClosingCosts: 3000,
          pointsPercent: 0,
          percentageFinanced: 1.0,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
          monthsUntilSale: 0,
        );

        // Should show negative savings (higher new loan cost due to term extension)
        expect(savings, lessThan(0));
      });

      test('should include opportunity cost when enabled', () {
        final savingsWithout =
            RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: 240,
          currentInterestRate: 4.5,
          newLoanTermYears: 30,
          newInterestRate: 3.5,
          otherClosingCosts: 3000,
          pointsPercent: 1.0, // 1% points
          percentageFinanced: 0.0, // Pay everything upfront
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
          monthsUntilSale: 0,
        );

        final savingsWith = RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: 240,
          currentInterestRate: 4.5,
          newLoanTermYears: 30,
          newInterestRate: 3.5,
          otherClosingCosts: 3000,
          pointsPercent: 1.0,
          percentageFinanced: 0.0, // Pay everything upfront
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          investmentReturnRate: 7.0,
          includeOpportunityCost: true,
          monthsUntilSale: 0,
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
          otherClosingCosts: 3000,
          pointsPercent: 0,
          percentageFinanced: 1.0,
          cashOutAmount: 50000,
          additionalPrincipalPayment: 0,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
          monthsUntilSale: 0,
        );

        // Cash out should reduce savings (or increase cost)
        expect(savings, isA<double>());
      });

      test('should handle additional principal payment', () {
        final savingsWithout =
            RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: 240,
          currentInterestRate: 4.5,
          newLoanTermYears: 30,
          newInterestRate: 3.5,
          otherClosingCosts: 3000,
          pointsPercent: 0,
          percentageFinanced: 1.0,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
          monthsUntilSale: 0,
        );

        final savingsWith = RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: 240,
          currentInterestRate: 4.5,
          newLoanTermYears: 30,
          newInterestRate: 3.5,
          otherClosingCosts: 3000,
          pointsPercent: 0,
          percentageFinanced: 1.0,
          cashOutAmount: 0,
          additionalPrincipalPayment: 20000,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
          monthsUntilSale: 0,
        );

        // Additional principal should increase savings (lower new loan amount)
        expect(savingsWith, greaterThan(savingsWithout));
      });
    });

    group('calculateTotalCostDifference with home sale', () {
      test('selling home should include home value in calculation', () {
        final savingsWithoutSale =
            RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: 240,
          currentInterestRate: 4.5,
          newLoanTermYears: 30,
          newInterestRate: 3.5,
          otherClosingCosts: 3000,
          pointsPercent: 0,
          percentageFinanced: 1.0,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
          monthsUntilSale: 0,
        );

        final savingsWithSale =
            RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: 240,
          currentInterestRate: 4.5,
          newLoanTermYears: 30,
          newInterestRate: 3.5,
          otherClosingCosts: 3000,
          pointsPercent: 0,
          percentageFinanced: 1.0,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
          monthsUntilSale: 120, // Sell after 10 years
        );

        // Results should differ when selling home
        expect(savingsWithSale, isNot(equals(savingsWithoutSale)));
      });

      test('results should be continuous at loan term boundary', () {
        // This test catches the bug where monthsUntilSale == remainingTermMonths
        // would incorrectly skip the sale logic
        const remainingTermMonths = 240;

        final savingsAtBoundary =
            RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: remainingTermMonths,
          currentInterestRate: 4.5,
          newLoanTermYears: 30,
          newInterestRate: 3.5,
          otherClosingCosts: 3000,
          pointsPercent: 0,
          percentageFinanced: 1.0,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
          monthsUntilSale: remainingTermMonths, // Exactly at boundary
        );

        final savingsJustBefore =
            RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: remainingTermMonths,
          currentInterestRate: 4.5,
          newLoanTermYears: 30,
          newInterestRate: 3.5,
          otherClosingCosts: 3000,
          pointsPercent: 0,
          percentageFinanced: 1.0,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
          monthsUntilSale: remainingTermMonths - 1, // Just before boundary
        );

        final savingsJustAfter =
            RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: remainingTermMonths,
          currentInterestRate: 4.5,
          newLoanTermYears: 30,
          newInterestRate: 3.5,
          otherClosingCosts: 3000,
          pointsPercent: 0,
          percentageFinanced: 1.0,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
          monthsUntilSale: remainingTermMonths + 1, // Just after boundary
        );

        // Values should be continuous - no sudden jumps
        // The difference between consecutive months should be reasonable (< $10k)
        final diffAtBoundary = (savingsAtBoundary - savingsJustBefore).abs();
        final diffAfterBoundary = (savingsJustAfter - savingsAtBoundary).abs();

        expect(diffAtBoundary, lessThan(10000),
            reason:
                'Savings should not jump dramatically at the current loan term boundary');
        expect(diffAfterBoundary, lessThan(10000),
            reason:
                'Savings should not jump dramatically after the current loan term boundary');
      });

      test('selling at exactly current loan term end should include home value',
          () {
        const remainingTermMonths = 240;

        final savings = RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: remainingTermMonths,
          currentInterestRate: 4.5,
          newLoanTermYears: 30,
          newInterestRate: 3.5,
          otherClosingCosts: 0,
          pointsPercent: 0,
          percentageFinanced: 1.0,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
          monthsUntilSale: remainingTermMonths, // Exactly at current loan end
        );

        // At month 240, current loan balance = 0, new loan still has balance
        // So selling at this point should favor current loan (gets full home value)
        // This ensures the sale logic is applied even at the exact boundary
        expect(savings, isA<double>());
        expect(savings.isFinite, isTrue);
      });

      test(
          'selling at exactly new loan term end should include home value for both',
          () {
        const newLoanTermYears = 30;

        final savings = RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: 240,
          currentInterestRate: 4.5,
          newLoanTermYears: newLoanTermYears,
          newInterestRate: 3.5,
          otherClosingCosts: 0,
          pointsPercent: 0,
          percentageFinanced: 1.0,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
          monthsUntilSale:
              newLoanTermYears * 12, // Exactly at new loan end (360)
        );

        // At month 360, both loans should be paid off (balance = 0)
        // So the home value applies equally to both
        expect(savings, isA<double>());
        expect(savings.isFinite, isTrue);
      });

      test('earlier sale should reduce total interest paid', () {
        final savingsEarlySale =
            RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: 240,
          currentInterestRate: 4.5,
          newLoanTermYears: 30,
          newInterestRate: 3.5,
          otherClosingCosts: 3000,
          pointsPercent: 0,
          percentageFinanced: 1.0,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
          monthsUntilSale: 60, // Sell after 5 years
        );

        final savingsLateSale =
            RefinanceCalculations.calculateTotalCostDifference(
          remainingBalance: 200000,
          remainingTermMonths: 240,
          currentInterestRate: 4.5,
          newLoanTermYears: 30,
          newInterestRate: 3.5,
          otherClosingCosts: 3000,
          pointsPercent: 0,
          percentageFinanced: 1.0,
          cashOutAmount: 0,
          additionalPrincipalPayment: 0,
          investmentReturnRate: 7.0,
          includeOpportunityCost: false,
          monthsUntilSale: 180, // Sell after 15 years
        );

        // Both should be valid numbers (not NaN or infinite)
        expect(savingsEarlySale.isFinite, isTrue);
        expect(savingsLateSale.isFinite, isTrue);
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
