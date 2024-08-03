import 'dart:math';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ml_dataframe/ml_dataframe.dart';
import 'package:ml_linalg/linalg.dart';
import 'package:rent_vs_buy/radio_data.dart';
import 'package:rent_vs_buy/rent_vs_buy.dart';
import 'package:rent_vs_buy/slider_data.dart';
import 'package:rent_vs_buy/switch_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

import 'chart.dart';
import 'utils.dart';

class RentVsBuyManager extends ChangeNotifier {
  final SharedPreferencesAsync preferences = SharedPreferencesAsync();
  final changes = ChangeStack();

  // Result of the calculation.
  double rentVsBuyValue = 0.0;
  DataFrame? result;
  double rentalCumulativeOpportunity = 0.0;
  double homeCumulativeOpportunity = 0.0;
  double totalHomeAssetsCumulative = 0.0;
  double totalHomeLiabilityCumulative = 0.0;
  double totalRentAssetsCumulative = 0.0;
  double totalRentLiabilityCumulative = 0.0;

  // RentVsBuy.calculate args
  SwitchData filingJointly = SwitchData(
    title: "Filing Jointly",
    value: false,
    popoverDescription: "Whether you file your taxes jointly.",
  );
  RadioData investmentTaxRate = RadioData(
    title: "Capital Gains Tax",
    value: 0.15,
    options: [0, 0.15, 0.2],
    popoverDescription:
        "The percentage you pay in capital gains tax on investments.",
  );
  RadioData marginalTaxRate = RadioData(
    title: "Marginal Tax",
    value: 0.22,
    options: [0.1, 0.12, 0.22, 0.24, 0.32, 0.35, 0.37],
    popoverDescription: "The percentage you pay in income taxes.",
  );
  Set<String> requiredSliders = {
    "years",
    "homePriceAmount",
    "monthlyRentAmount",
    "downPaymentRate",
    "lengthOfMortgage",
    "mortgageRate",
    "homePriceGrowthRate",
    "investmentReturnRate",
  };
  Map<String, SliderData> sliders = {
    "years": SliderData(
      title: "Years",
      value: 30,
      min: 1,
      max: 30,
      divisions: 29,
      numberType: NumberType.decimal,
      popoverDescription: "The number of years you plan on owning the house.",
    ),
    "homePriceAmount": SliderData(
      title: "Home Price",
      value: 260000.00,
      numberType: NumberType.dollar,
      min: 0,
      max: 2000000,
      popoverDescription: "The price of the home when purchasing in USD.",
    ),
    "monthlyRentAmount": SliderData(
      title: "Monthly Rent",
      value: 1800.0,
      numberType: NumberType.dollar,
      min: 0.0,
      max: 10000,
      popoverDescription:
          "The amount of rent paid monthly if you were not to purchase a home.",
    ),
    "downPaymentRate": SliderData(
      title: "Downpayment",
      value: 0.2,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 1.0,
      popoverDescription:
          "The percentage of the home price you pay as a downpayment.",
    ),
    "lengthOfMortgage": SliderData(
      title: "Mortgage Length",
      value: 30,
      min: 15,
      max: 30,
      divisions: 15,
      numberType: NumberType.decimal,
      popoverDescription: "The number of years the mortgage will last.",
    ),
    "mortgageRate": SliderData(
      title: "Mortgage Rate",
      value: 0.07,
      numberType: NumberType.percentage,
      min: 0,
      max: 0.1,
      popoverDescription: "The (percent) interest rate paid on the mortgage.",
    ),
    "homePriceGrowthRate": SliderData(
      title: "Home Price Growth",
      value: 0.03,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.2,
      divisions: 20,
      popoverDescription: "The rate at which the home appreciates annually.",
    ),
    "investmentReturnRate": SliderData(
      title: "Investment Return",
      value: 0.08,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.2,
      divisions: 20,
      popoverDescription:
          "The return rate for a hypothetical investment you could make if you didn't purchase the home (opportunity cost).",
    ),
    "financedFeesAmount": SliderData(
      title: "Financed Fees",
      value: 1000.00,
      numberType: NumberType.dollar,
      min: 0,
      max: 50000,
      divisions: 50,
      popoverDescription:
          "The value of any other fees financed as part of the home loan (i.e. VA loans).",
    ),
    "pointsRate": SliderData(
      title: "Points",
      value: 0.00,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.1,
      popoverDescription:
          "The percentage of the loan paid in points at closing.",
    ),
    "pmiRate": SliderData(
      title: "PMI",
      value: 0.005,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.01,
      popoverDescription:
          "The percentage of the home loan paid in primary mortgage insurance costs.",
    ),
    "rentGrowthRate": SliderData(
      title: "Rent Growth",
      value: 0.02,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.2,
      divisions: 20,
      popoverDescription: "The rate at which rent prices grow annually.",
    ),
    "inflationRate": SliderData(
      title: "Inflation Rate",
      value: 0.02,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.1,
      divisions: 10,
      popoverDescription: "The rate at which inflation rates grow annually.",
    ),
    "propertyTaxRate": SliderData(
      title: "Property Tax",
      value: 0.0125,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.1,
      divisions: 100,
      popoverDescription:
          "The percentage of the home price paid in taxes annually.",
    ),
    "costsOfBuyingHomeRate": SliderData(
      title: "Buying Costs",
      value: 0.03,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.1,
      divisions: 20,
      popoverDescription:
          "The percentage of the home price paid in upfront buying costs.",
    ),
    "costsOfSellingHomeRate": SliderData(
      title: "Selling Costs",
      value: 0.03,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.1,
      divisions: 20,
      popoverDescription:
          "The percentage of the home price paid at closing in selling costs.",
    ),
    "maintenanceRate": SliderData(
      title: "Maintenance",
      value: 0.01,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.1,
      divisions: 20,
      popoverDescription:
          "The percentage of the home price paid in maintenance costs annually.",
    ),
    "homeOwnersInsuranceRate": SliderData(
      title: "Homeowners Insurance",
      value: 0.004,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.01,
      divisions: 50,
      popoverDescription:
          "The percentage of the home price paid in home owners insurance costs annually.",
    ),
    "monthlyUtilitiesAmount": SliderData(
      title: "Monthly Utilities",
      value: 200.0,
      numberType: NumberType.dollar,
      min: 0.0,
      max: 2000,
      popoverDescription:
          "The amount of utility costs monthly. Note, this will be a cost for both purchasing a home and buying a home - so the net gain will be \$0. It is included so the monthly cashflows are correct.",
    ),
    "monthlyCommonFeesAmount": SliderData(
      title: "Monthly Common Fees",
      value: 200.0,
      numberType: NumberType.dollar,
      min: 0.0,
      max: 2000,
      popoverDescription: "The amount of common fee costs monthly (i.e. HOA).",
    ),
    "securityDepositRate": SliderData(
      title: "Security Deposit",
      value: 1.0,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 2.0,
      divisions: 2,
      popoverDescription:
          "The percentage of first month's rent paid as a security deposit.",
    ),
    "brokersFeeRate": SliderData(
      title: "Brokers Fee",
      value: 0.00,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.1,
      divisions: 20,
      popoverDescription:
          "The percentage of first month's rent paid as a broker's fee for renting.",
    ),
    "rentersInsuranceRate": SliderData(
      title: "Renters Insurance",
      value: 0.01,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.1,
      divisions: 20,
      popoverDescription:
          "The percentage of monthly rent amount paid as a rental insurance.",
    )
  };

  void fromPreferences() async {
    filingJointly.value =
        await preferences.getBool("filingJointly") ?? filingJointly.value;
    investmentTaxRate.value =
        await preferences.getDouble("investmentTaxRate") ??
            investmentTaxRate.value;
    marginalTaxRate.value =
        await preferences.getDouble("marginalTaxRate") ?? marginalTaxRate.value;
    for (int i = 0; i < sliders.length; i++) {
      String key = sliders.keys.elementAt(i);
      final data = await preferences.getDouble(key);
      if (data != null) {
        sliders[key]?.value = data;
      }
    }
    onChanged();
  }

  void reset() {
    filingJointly.value = false;
    investmentTaxRate.value = investmentTaxRate.defaultValue;
    marginalTaxRate.value = marginalTaxRate.defaultValue;
    for (int i = 0; i < sliders.length; i++) {
      sliders.values.elementAt(i).value =
          sliders.values.elementAt(i).defaultValue;
    }
  }

  void toPreferences() async {
    await preferences.setDouble("investmentTaxRate", investmentTaxRate.value);
    await preferences.setDouble("marginalTaxRate", marginalTaxRate.value);
    await preferences.setBool("filingJointly", filingJointly.value);
    for (int i = 0; i < sliders.length; i++) {
      String key = sliders.keys.elementAt(i);
      double value = sliders.values.elementAt(i).value;
      await preferences.setDouble(key, value);
    }
  }

  String createCSV() {
    final rowData = result?.rows
        .map((i) => i
            .map((j) =>
                NumberFormat.decimalPatternDigits(decimalDigits: 2).format(j))
            .toList())
        .toList();
    final header = result?.header.toList();
    if (header != null) {
      rowData?.insert(0, header);
    }
    return const ListToCsvConverter().convert(rowData);
  }

  void copy() async {
    final csv = createCSV();
    await Clipboard.setData(ClipboardData(text: csv));
  }

  void onInit() {
    fromPreferences();
    onChanged();
  }

  DataFrame calculate() {
    return _calculate(
      filingJointly: filingJointly,
      investmentTaxRate: investmentTaxRate,
      marginalTaxRate: marginalTaxRate,
      sliders: sliders,
    );
  }

  static DataFrame _calculate({
    required SwitchData filingJointly,
    required RadioData investmentTaxRate,
    required RadioData marginalTaxRate,
    required Map<String, SliderData> sliders,
  }) {
    final result = RentVsBuy.calculate(
      homePriceAmount: sliders["homePriceAmount"]!.value,
      financedFeesAmount: sliders["financedFeesAmount"]!.value,
      years: sliders["years"]!.value.toInt(),
      mortgageRate: sliders["mortgageRate"]!.value,
      downPaymentRate: sliders["downPaymentRate"]!.value,
      pointsRate: sliders["pointsRate"]!.value,
      pmiRate: sliders["pmiRate"]!.value,
      lengthOfMortgage: sliders["lengthOfMortgage"]!.value.toInt(),
      homePriceGrowthRate: sliders["homePriceGrowthRate"]!.value,
      rentGrowthRate: sliders["rentGrowthRate"]!.value,
      investmentReturnRate: sliders["investmentReturnRate"]!.value,
      investmentTaxRate: investmentTaxRate.value,
      inflationRate: sliders["inflationRate"]!.value,
      filingJointly: filingJointly.value,
      propertyTaxRate: sliders["propertyTaxRate"]!.value,
      marginalTaxRate: marginalTaxRate.value,
      costsOfBuyingHomeRate: sliders["costsOfBuyingHomeRate"]!.value,
      costsOfSellingHomeRate: sliders["costsOfSellingHomeRate"]!.value,
      maintenanceRate: sliders["maintenanceRate"]!.value,
      homeOwnersInsuranceRate: sliders["homeOwnersInsuranceRate"]!.value,
      monthlyUtilitiesAmount: sliders["monthlyUtilitiesAmount"]!.value,
      monthlyCommonFeesAmount: sliders["monthlyCommonFeesAmount"]!.value,
      monthlyRentAmount: sliders["monthlyRentAmount"]!.value,
      securityDepositRate: sliders["securityDepositRate"]!.value,
      brokersFeeRate: sliders["brokersFeeRate"]!.value,
      rentersInsuranceRate: sliders["rentersInsuranceRate"]!.value,
    );
    return result;
  }

  void onChanged() {
    result = calculate();
    rentVsBuyValue = result?["buyVsRent"].data.last;
    homeCumulativeOpportunity = result?["homeCumulativeOpportunity"].data.last;
    rentalCumulativeOpportunity =
        result?["rentalCumulativeOpportunity"].data.last;
    totalHomeAssetsCumulative = result?["totalHomeAssetsCumulative"].data.last;
    totalHomeLiabilityCumulative =
        result?["totalHomeLiabilityCumulative"].data.last;
    totalRentAssetsCumulative = result?["totalRentAssetsCumulative"].data.last;
    totalRentLiabilityCumulative =
        result?["totalRentLiabilityCumulative"].data.last;
    notifyListeners();
  }

  static ChartData calculateChart({
    required String key,
    required SliderData data,
    required SwitchData filingJointly,
    required RadioData investmentTaxRate,
    required RadioData marginalTaxRate,
    required Map<String, SliderData> sliders,
  }) {
    const maxLength = 40;
    var slidersCopy = Map.fromEntries(
      sliders.entries.map(
        (i) => MapEntry(
          i.key,
          i.value.copy(),
        ),
      ),
    );
    List<ChartSpot> spots = [];
    final grid = [
      ...linspace(
        start: data.min,
        stop: data.max,
        num: min(maxLength, data.divisions),
        endpoint: false,
      ),
      data.max,
    ];
    for (double gridItem in grid) {
      slidersCopy[key]!.value = gridItem;
      final value = _calculate(
        filingJointly: filingJointly,
        investmentTaxRate: investmentTaxRate,
        marginalTaxRate: marginalTaxRate,
        sliders: slidersCopy,
      )["buyVsRent"]
          .data
          .last;
      spots.add(
        ChartSpot(
          index: gridItem,
          value: value,
        ),
      );
    }
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
      series: "buyVsRent",
      minY: smallest,
      maxY: largest,
      minX: data.min,
      maxX: data.max,
      length: grid.length,
    );
  }

  void onChangeEnd() {
    toPreferences();
  }
}
