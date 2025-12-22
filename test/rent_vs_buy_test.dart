import 'package:flutter_test/flutter_test.dart';
import 'package:finance_calculator/rent_vs_buy.dart';

void main() {
  group('RentVsBuy Utility Methods', () {
    test('annualToMonthly converts rates correctly', () {
      expect(RentVsBuy.annualToMonthly(rate: 0.12), closeTo(0.01, 0.0001));
      expect(RentVsBuy.annualToMonthly(rate: 0.06), closeTo(0.005, 0.0001));
      expect(RentVsBuy.annualToMonthly(rate: 0.0), 0.0);
    });

    test('monthlyToAnnual converts rates correctly', () {
      expect(RentVsBuy.monthlyToAnnual(rate: 0.01), closeTo(0.12, 0.0001));
      expect(RentVsBuy.monthlyToAnnual(rate: 0.005), closeTo(0.06, 0.0001));
      expect(RentVsBuy.monthlyToAnnual(rate: 0.0), 0.0);
    });

    test('maxZero returns correct values', () {
      expect(RentVsBuy.maxZero(5.0), 5.0);
      expect(RentVsBuy.maxZero(-5.0), 0.0);
      expect(RentVsBuy.maxZero(0.0), 0.0);
    });
  });

  group('RentVsBuy Main Calculation', () {
    test('calculate returns DataFrame with correct columns', () {
      final result = RentVsBuy.calculate();
      expect(result.header, contains('per'));
      expect(result.header, contains('homeValue'));
      expect(result.header, contains('totalHomeLiability'));
      expect(result.header, contains('totalRentLiability'));
      expect(result.header, contains('buyVsRent'));
    });

    test('calculate handles zero values correctly', () {
      final result = RentVsBuy.calculate(
        homePriceAmount: 0.0,
        monthlyRentAmount: 0.0,
        mortgageRate: 0.0,
        homePriceGrowthRate: 0.0,
        rentGrowthRate: 0.0,
        investmentReturnRate: 0.0,
      );

      // Verify some key calculations
      final homeValue = result['homeValue'].data;
      final rent = result['rent'].data;

      expect(homeValue.first, 0.0);
      expect(rent.first, 0.0);
    });

    test('calculate handles edge cases', () {
      final result = RentVsBuy.calculate(
        years: 1, // Short time period
        downPaymentRate: 1.0, // Full down payment
        mortgageRate: 0.0, // No interest
        financedFeesAmount: 0.0, // No financed fees
      );

      // With full down payment, no interest, and no financed fees,
      // principal and interest payments should be zero
      final ppmt = result['ppmt'].data;
      final ipmt = result['ipmt'].data;

      expect(ppmt.every((value) => value == 0.0), isTrue);
      expect(ipmt.every((value) => value == 0.0), isTrue);
    });

    test('calculate handles tax scenarios correctly', () {
      final result = RentVsBuy.calculate(
        homePriceAmount: 1000000.0,
        propertyTaxRate: 0.02,
        marginalTaxRate: 0.3,
        filingJointly: true,
      );

      final propertyTaxes = result['propertyTaxes'].data;
      final homeTaxCredit = result['homeTaxCredit'].data;

      // Property taxes should be calculated correctly
      expect(propertyTaxes.first, closeTo(1000000.0 * 0.02 / 12, 0.01));

      // Tax credits should be present
      expect(homeTaxCredit.any((value) => value > 0), isTrue);
    });

    test('calculate handles opportunity cost correctly', () {
      final result = RentVsBuy.calculate(
        homePriceAmount: 500000.0,
        monthlyRentAmount: 2000.0,
        investmentReturnRate: 0.08,
      );

      final homeOpportunityCost = result['homeOpportunityCost'].data;
      final rentalOpportunityCost = result['rentalOpportunityCost'].data;

      // Opportunity costs should be calculated
      expect(homeOpportunityCost.any((value) => value > 0), isTrue);
      expect(rentalOpportunityCost.any((value) => value > 0), isTrue);
    });

    test('calculate handles PMI correctly', () {
      final result = RentVsBuy.calculate(
        homePriceAmount: 500000.0,
        downPaymentRate: 0.1, // Less than 20% down payment
        pmiRate: 0.01,
      );

      final pmi = result['pmi'].data.toList();
      final remainingHomePricePercentage =
          result['remainingHomePricePercentage'].data.toList();

      // PMI should be present when down payment is less than 20%
      expect(pmi.any((value) => value > 0), isTrue);

      // PMI should stop when equity reaches 20%
      final pmiCutoffIndex = remainingHomePricePercentage
          .indexWhere((value) => value >= RentVsBuy.pmiCutoffRate);
      if (pmiCutoffIndex != -1) {
        expect(
            pmi.sublist(pmiCutoffIndex).every((value) => value == 0), isTrue);
      }
    });
  });
}
