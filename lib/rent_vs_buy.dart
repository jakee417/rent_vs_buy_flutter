import 'dart:math';
import 'package:ml_dataframe/ml_dataframe.dart';
import 'package:ml_linalg/vector.dart';
import 'utils.dart';

class RentVsBuy {
  static const periods = 12;
  static const singleStandardDeductionAmount = 12950;
  static const jointStandardDeductionAmount = 25900;
  static const taxCreditLimitAmount = 750000;
  static const pmiCutoffRate = 0.2;
  static final finance = FinanceVector();

  static double annualToMonthly({required double rate, int periods = periods}) {
    return rate / periods;
  }

  static double monthlyToAnnual({required double rate, int periods = periods}) {
    return rate * periods;
  }

  static double maxZero(double i) {
    return i < 0 ? 0 : i;
  }

  static DataFrame calculate(
      {double homePriceAmount = 250000.00,
      double financedFeesAmount = 1000.00,
      int years = 30,
      double mortgageRate = 0.035,
      double downPaymentRate = 0.15,
      double pointsRate = 0.03,
      double pmiRate = 0.005,
      int lengthOfMortgage = 30,
      double homePriceGrowthRate = 0.03,
      double rentGrowthRate = 0.02,
      double investmentReturnRate = 0.04,
      double investmentTaxRate = 0.15,
      double inflationRate = 0.02,
      bool filingJointly = false,
      double propertyTaxRate = 0.0135,
      double marginalTaxRate = 0.2,
      double costsOfBuyingHomeRate = 0.04,
      double costsOfSellingHomeRate = 0.03,
      double maintenanceRate = 0.01,
      double homeOwnersInsuranceRate = 0.004,
      double monthlyUtilitiesAmount = 100.00,
      double monthlyCommonFeesAmount = 100.00,
      double monthlyRentAmount = 1000.00,
      double securityDepositRate = 1.0,
      double brokersFeeRate = 0.01,
      double rentersInsuranceRate = 0.01}) {
    // ########################################################################
    // Initial variables.
    // ########################################################################
    var loan = homePriceAmount * (1.0 - downPaymentRate);
    final down = homePriceAmount - loan;
    loan += financedFeesAmount;

    // ########################################################################
    // Convert to monthly rates.
    // ########################################################################
    mortgageRate = annualToMonthly(rate: mortgageRate);
    homePriceGrowthRate = annualToMonthly(rate: homePriceGrowthRate);
    rentGrowthRate = annualToMonthly(rate: rentGrowthRate);
    investmentReturnRate = annualToMonthly(rate: investmentReturnRate);
    inflationRate = annualToMonthly(rate: inflationRate);
    propertyTaxRate = annualToMonthly(rate: propertyTaxRate);
    marginalTaxRate = annualToMonthly(rate: marginalTaxRate);
    maintenanceRate = annualToMonthly(rate: maintenanceRate);
    homeOwnersInsuranceRate = annualToMonthly(rate: homeOwnersInsuranceRate);
    pmiRate = annualToMonthly(rate: pmiRate);

    // ########################################################################
    // Period Counters.
    // ########################################################################
    final n = years * periods;
    final per = Vector.fromList(List.generate(n, (i) => i));
    final distinctYears = Vector.fromList(List.generate(years, (i) => i));
    final annualPer = Vector.fromList(List.generate(
        distinctYears.length * periods, (i) => distinctYears[i ~/ periods]));
    final mortgagePer = Vector.fromList(
        List.generate(lengthOfMortgage * periods + 1, (i) => i).sublist(1));
    final perInv = per * -1 + n;

    // ########################################################################
    // Home Value.
    // ########################################################################
    final homeValue = finance.fvNper(
        rate: homePriceGrowthRate, nper: per, pmt: 0, pv: -homePriceAmount);

    // ########################################################################
    // Home Liabilities.
    // ########################################################################
    // Fixed costs at the beginning of the loan period.
    final downFee = Vector.fromList([
      ...[down],
      ...List.filled(n - 1, 0)
    ]);
    final buyingClosingCosts = Vector.fromList([
      ...[homePriceAmount * costsOfBuyingHomeRate],
      ...List.filled(n - 1, 0)
    ]);
    final points = Vector.fromList([
      ...[loan * pointsRate],
      ...List.filled(n - 1, 0)
    ]);
    final monthlyCommonFees = finance.fvNper(
        rate: monthlyToAnnual(rate: inflationRate),
        nper: annualPer,
        pmt: 0,
        pv: -monthlyCommonFeesAmount);
    final homeMonthlyUtilities = finance.fvNper(
        rate: monthlyToAnnual(rate: inflationRate),
        nper: annualPer,
        pmt: 0,
        pv: -monthlyUtilitiesAmount);
    // Helper variable for the home value in the first month of each year.
    var firstMonthHomeValues = List<num>.from(homeValue, growable: false);
    for (int i = 0; i < homeValue.length; i += 1) {
      firstMonthHomeValues[i] = homeValue[i ~/ periods];
    }
    // Variable costs based off home price in first month of each year.
    final firstMonthHomeValue = Vector.fromList(firstMonthHomeValues);
    final propertyTaxes = firstMonthHomeValue * propertyTaxRate;
    final maintenance = firstMonthHomeValue * maintenanceRate;
    final insurance = firstMonthHomeValue * homeOwnersInsuranceRate;
    // Mortgage costs.
    final ppmt = finance
        .ppmtPer(
          rate: mortgageRate,
          per: mortgagePer,
          nper: lengthOfMortgage * periods,
          pv: -loan,
          padding: max(years - lengthOfMortgage, 0) * periods,
        )
        .subvector(0, years * periods);
    final cuPPmt = cumulativeSum(ppmt);
    final ipmt = finance
        .ipmtPer(
          rate: mortgageRate,
          per: mortgagePer,
          nper: lengthOfMortgage * periods,
          pv: -loan,
          padding: max(years - lengthOfMortgage, 0) * periods,
        )
        .subvector(0, years * periods);
    final pmt = ppmt + ipmt;
    final remainingHomePricePercentage = (cuPPmt + down) / homePriceAmount;
    final pmiMask = remainingHomePricePercentage
        .mapToVector((i) => (i < pmiCutoffRate) ? 1 : 0);
    final pmi = pmiMask * pmiRate * loan;
    // Fixed costs at the end of the loan period.
    final sellersFee = Vector.fromList([
      ...List.filled(n - 1, 0),
      ...[homeValue.last * costsOfSellingHomeRate],
    ]);
    final loanPayoff = Vector.fromList([
      ...List.filled(n - 1, 0),
      ...[loan - cuPPmt.last],
    ]);
    final totalHomeLiability = pmt +
        maintenance +
        insurance +
        propertyTaxes +
        monthlyCommonFees +
        buyingClosingCosts +
        points +
        downFee +
        homeMonthlyUtilities +
        pmi +
        sellersFee +
        loanPayoff;
    final totalHomeLiabilityCumulative = cumulativeSum(totalHomeLiability);

    // ########################################################################
    // Home Assets.
    // ########################################################################
    // Calculate the annual interest we pay.
    var annualIpmtValues = List.filled(years, 0.0);
    for (int i = 0; i < years; i++) {
      var sum = 0.0;
      for (int j = 0; j < periods; j++) {
        sum += ipmt[i * periods + j];
      }
      annualIpmtValues[i] = sum;
    }
    var annualIpmt = Vector.fromList(annualIpmtValues);
    // Mask for where we exceed the tax credit limit.
    final taxCreditLimit = cumulativeSum(annualIpmt)
        .mapToVector((i) => (i <= taxCreditLimitAmount) ? 1 : 0);
    // Mask annual interest sum where we have not exceeded the tax credit limit.
    annualIpmt *= taxCreditLimit;
    final standardDeduction = finance.fvNper(
      rate: monthlyToAnnual(rate: inflationRate),
      nper: distinctYears,
      pmt: 0,
      pv: -(filingJointly
          ? jointStandardDeductionAmount
          : singleStandardDeductionAmount),
    );
    // The benefit is anything in excess of the standard deduction.
    final mortgageInterestAnnual =
        (annualIpmt - standardDeduction).mapToVector((i) => i < 0 ? 0 : i) *
            marginalTaxRate;
    // Apply the tax credit at the end of the year.
    var mortgageInterestMonthly = List.filled(n, 0.0);
    for (int i = 0; i < years; i++) {
      mortgageInterestMonthly[i * periods + (periods - 1)] =
          mortgageInterestAnnual[i];
    }
    final mortgageInterest = Vector.fromList(mortgageInterestMonthly);
    // Sell the house in the last month.
    final homeSale = Vector.fromList([
      ...List.filled(n - 1, 0),
      ...[homeValue.last],
    ]);
    final totalHomeAssets = homeSale + mortgageInterest;
    final totalHomeAssetsCumulative = cumulativeSum(totalHomeAssets);

    // ########################################################################
    // Rent Liabilities.
    // ########################################################################
    final rent = finance.fvNper(
        rate: monthlyToAnnual(rate: rentGrowthRate),
        nper: annualPer,
        pmt: 0,
        pv: -monthlyRentAmount);
    final securityDepositLiability = Vector.fromList([
      ...[securityDepositRate * monthlyRentAmount],
      ...List.filled(n - 1, 0)
    ]);
    final rentersInsurance = rent * rentersInsuranceRate;
    final brokersFeeCost = rent * brokersFeeRate;
    final totalRentLiability =
        rent + securityDepositLiability + rentersInsurance + brokersFeeCost;
    final totalRentLiabilityCumulative = cumulativeSum(totalRentLiability);

    // ########################################################################
    // Rent Assets.
    // ########################################################################
    var securityDepositAsset = List.filled(n, 0.0);
    securityDepositAsset.last = securityDepositRate * monthlyRentAmount;
    final totalRentAssets = Vector.fromList(securityDepositAsset);
    final totalRentAssetsCumulative = cumulativeSum(totalRentAssets);

    // ########################################################################
    // Opportunity Cost.
    // ########################################################################
    final homeOpportunityCost = ((totalHomeLiability - totalHomeAssets) -
            (totalRentLiability - totalRentAssets))
        .mapToVector(maxZero);
    final rentalOpportunityCost = ((totalRentLiability - totalRentAssets) -
            (totalHomeLiability - totalHomeAssets))
        .mapToVector(maxZero);
    // Compute the future value of these cash flows.
    final homeOpportunityCostFv = finance.fvNperPv(
        rate: investmentReturnRate,
        nper: perInv,
        pmt: 0,
        pv: homeOpportunityCost * -1);
    final rentalOpportunityCostFv = finance.fvNperPv(
        rate: investmentReturnRate,
        nper: perInv,
        pmt: 0,
        pv: rentalOpportunityCost * -1);
    // Apply a tax to the investment earnings.
    final homeOpportunityCostFvPostTax = maximum(
        homeOpportunityCostFv * (1.0 - investmentTaxRate), homeOpportunityCost);
    final rentalOpportunityCostFvPostTax = maximum(
        rentalOpportunityCostFv * (1.0 - investmentTaxRate),
        rentalOpportunityCost);
    // Compute cumulative values.
    final rentalCumulativeOpportunity =
        cumulativeSum(rentalOpportunityCostFvPostTax);
    final homeCumulativeOpportunity =
        cumulativeSum(homeOpportunityCostFvPostTax);
    // Buy vs. Rent is our equity - costs - opportunity cost.
    final buyVsRent = rentalCumulativeOpportunity - homeCumulativeOpportunity;

    // ########################################################################
    // Create DataFrame Result.
    // ########################################################################
    var df = DataFrame(per.toList().map((i) => [i]),
        headerExists: false, header: ["per"]);
    df = df.addSeries(Series("annualPer", annualPer));
    df = df.addSeries(Series("perInv", perInv));
    df = df.addSeries(Series("homeValue", homeValue));
    df = df.addSeries(Series("downFee", downFee));
    df = df.addSeries(Series("buyingClosingCosts", buyingClosingCosts));
    df = df.addSeries(Series("points", points));
    df = df.addSeries(Series("monthlyCommonFees", monthlyCommonFees));
    df = df.addSeries(Series("firstMonthHomeValue", firstMonthHomeValue));
    df = df.addSeries(Series("propertyTaxes", propertyTaxes));
    df = df.addSeries(Series("maintenance", maintenance));
    df = df.addSeries(Series("insurance", insurance));
    df = df.addSeries(Series("ppmt", ppmt));
    df = df.addSeries(Series("ipmt", ipmt));
    df = df.addSeries(Series("pmt", pmt));
    df = df.addSeries(Series("pmi", pmi));
    df = df.addSeries(Series("sellersFee", sellersFee));
    df = df.addSeries(Series("loanPayoff", loanPayoff));
    df = df.addSeries(Series("totalHomeLiability", totalHomeLiability));
    df = df.addSeries(Series("homeSale", homeSale));
    df = df.addSeries(Series("mortgageInterest", mortgageInterest));
    df = df.addSeries(Series("totalHomeAssets", totalHomeAssets));
    df = df.addSeries(Series("rent", rent));
    df = df.addSeries(
        Series("securityDepositLiability", securityDepositLiability));
    df = df.addSeries(Series("rentersInsurance", rentersInsurance));
    df = df.addSeries(Series("brokersFeeCost", brokersFeeCost));
    df = df.addSeries(Series("totalRentLiability", totalRentLiability));
    df = df.addSeries(Series("securityDepositAsset", securityDepositAsset));
    df = df.addSeries(Series("totalRentAsset", totalRentAssets));

    df = df.addSeries(
        Series("totalHomeAssetsCumulative", totalHomeAssetsCumulative));
    df = df.addSeries(
        Series("totalHomeLiabilityCumulative", totalHomeLiabilityCumulative));
    df = df.addSeries(
        Series("totalRentAssetsCumulative", totalRentAssetsCumulative));
    df = df.addSeries(
        Series("totalRentLiabilityCumulative", totalRentLiabilityCumulative));

    df = df.addSeries(Series("homeOpportunityCost", homeOpportunityCost));
    df = df.addSeries(Series("rentalOpportunityCost", rentalOpportunityCost));
    df = df.addSeries(Series("homeOpportunityCostFv", homeOpportunityCostFv));
    df = df
        .addSeries(Series("rentalOpportunityCostFv", rentalOpportunityCostFv));
    df = df.addSeries(
        Series("homeOpportunityCostFvPostTax", homeOpportunityCostFvPostTax));
    df = df.addSeries(Series(
        "rentalOpportunityCostFvPostTax", rentalOpportunityCostFvPostTax));
    df = df.addSeries(
        Series("homeCumulativeOpportunity", homeCumulativeOpportunity));
    df = df.addSeries(
        Series("rentalCumulativeOpportunity", rentalCumulativeOpportunity));
    df = df.addSeries(Series("buyVsRent", buyVsRent));
    return df;
  }
}
