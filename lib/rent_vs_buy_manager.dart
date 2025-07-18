import 'dart:math';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
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
import 'package:string_validator/string_validator.dart';
import 'package:undo/undo.dart';
import 'package:http/http.dart' as http;
import 'chart.dart';
import 'utils.dart';

final isWebMobile = kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

const smallSlider = 40;
const largeSlider = 200;

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
  SwitchData vaLoan = SwitchData(
    title: "VA Loan",
    value: false,
    popoverDescription:
        "Whether you are financing a VA loan. If you are using a VA loan, but not financing the fee, include this in 'Buying Costs'.",
  );
  SwitchData firstTimeHomebuyer = SwitchData(
    title: "First Time Homebuyer",
    value: true,
    popoverDescription:
        "Whether you are a first time homebuyer. Only used for VA loans.",
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
      max: 45,
      divisions: 44,
      numberType: NumberType.decimal,
      popoverDescription: "The number of years you plan on owning the house.",
    ),
    "homePriceAmount": SliderData(
      title: "Home Price",
      value: 260000.00,
      numberType: NumberType.dollar,
      min: 0,
      max: 4000000,
      popoverDescription: "The price of the home when purchasing in USD.",
      divisions: (largeSlider) * 2,
    ),
    "monthlyRentAmount": SliderData(
      title: "Monthly Rent",
      value: 1800.0,
      numberType: NumberType.dollar,
      min: 0.0,
      max: 10000,
      popoverDescription:
          "The amount of rent paid monthly if you were not to purchase a home.",
      divisions: largeSlider,
    ),
    "downPaymentRate": SliderData(
      title: "Downpayment",
      value: 0.2,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 1.0,
      popoverDescription:
          "The percentage of the home price you pay as a downpayment.",
      divisions: largeSlider,
      suffixVariableMultiplier: "homePriceAmount",
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
      divisions: largeSlider,
    ),
    "homePriceGrowthRate": SliderData(
      title: "Home Price Growth",
      value: 0.03,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.2,
      divisions: smallSlider,
      popoverDescription: "The rate at which the home appreciates annually.",
    ),
    "investmentReturnRate": SliderData(
      title: "Investment Return",
      value: 0.08,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.2,
      divisions: smallSlider,
      popoverDescription:
          "The return rate for a hypothetical investment you could make if you didn't purchase the home (opportunity cost).",
    ),
    "financedFeesAmount": SliderData(
      title: "Financed Fees",
      value: 1000.00,
      numberType: NumberType.dollar,
      min: 0,
      max: 50000,
      divisions: 100,
      popoverDescription:
          "The value of any other fees financed as part of the home loan. This is different than closing costs, which are not financed as part of the home loan. See 'Buying Costs' for more details.",
    ),
    "pointsRate": SliderData(
      title: "Points",
      value: 0.00,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.1,
      popoverDescription:
          "The percentage of the home loan paid in points at closing.",
      suffixVariableMultiplier: "loanAmount",
    ),
    "pmiRate": SliderData(
      title: "PMI",
      value: 0.005,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.01,
      popoverDescription:
          "The percentage of the home loan paid in primary mortgage insurance costs annually.",
      suffixVariableMultiplier: "loanAmount",
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
      divisions: 20,
      popoverDescription: "The rate at which inflation rates grow annually.",
    ),
    "propertyTaxRate": SliderData(
      title: "Property Tax",
      value: 0.0125,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.05,
      divisions: 100,
      popoverDescription:
          "The percentage of the home price paid in taxes annually.",
      suffixVariableMultiplier: "homePriceAmount",
    ),
    "costsOfBuyingHomeRate": SliderData(
      title: "Buying Costs",
      value: 0.03,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.05,
      divisions: largeSlider,
      popoverDescription:
          "The percentage of the home price paid in upfront buying costs.",
      suffixVariableMultiplier: "homePriceAmount",
    ),
    "costsOfSellingHomeRate": SliderData(
      title: "Selling Costs",
      value: 0.03,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.1,
      divisions: smallSlider,
      popoverDescription:
          "The percentage of the home price paid at closing in selling costs.",
      suffixVariableMultiplier: "homePriceAmount",
    ),
    "maintenanceRate": SliderData(
      title: "Maintenance",
      value: 0.01,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.03,
      divisions: smallSlider,
      popoverDescription:
          "The percentage of the home price paid in maintenance costs annually.",
      suffixVariableMultiplier: "homePriceAmount",
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
      suffixVariableMultiplier: "homePriceAmount",
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
      divisions: 4,
      popoverDescription:
          "The percentage of first month's rent paid as a security deposit.",
      suffixVariableMultiplier: "monthlyRentAmount",
    ),
    "brokersFeeRate": SliderData(
      title: "Brokers Fee",
      value: 0.00,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.1,
      divisions: smallSlider,
      popoverDescription:
          "The percentage of first month's rent paid as a broker's fee for renting.",
      suffixVariableMultiplier: "monthlyRentAmount",
    ),
    "rentersInsuranceRate": SliderData(
      title: "Renters Insurance",
      value: 0.01,
      numberType: NumberType.percentage,
      min: 0.0,
      max: 0.1,
      divisions: smallSlider,
      popoverDescription:
          "The percentage of monthly rent amount paid as a rental insurance.",
      suffixVariableMultiplier: "monthlyRentAmount",
    )
  };

  double suffixMultiplier(String suffixVariableMultiplier) {
    if (sliders.containsKey(suffixVariableMultiplier)) {
      return sliders[suffixVariableMultiplier]!.value;
    } else if (suffixVariableMultiplier == "loanAmount") {
      // loanAmount is a special case since we do not store this as a slider
      // so compute the loanAmount on the fly.
      return sliders["homePriceAmount"]!.value *
              (1 - sliders["downPaymentRate"]!.value) +
          sliders["financedFeesAmount"]!.value;
    }
    return 0.0;
  }

  void fromPreferences() async {
    filingJointly.value =
        await preferences.getBool("filingJointly") ?? filingJointly.value;
    investmentTaxRate.value =
        await preferences.getDouble("investmentTaxRate") ??
            investmentTaxRate.value;
    marginalTaxRate.value =
        await preferences.getDouble("marginalTaxRate") ?? marginalTaxRate.value;
    vaLoan.value = await preferences.getBool("vaLoan") ?? vaLoan.value;
    firstTimeHomebuyer.value =
        await preferences.getBool("firstTimeHomebuyer") ??
            firstTimeHomebuyer.value;
    for (int i = 0; i < sliders.length; i++) {
      String key = sliders.keys.elementAt(i);
      final data = await preferences.getDouble(key);
      if (data != null) {
        sliders[key]?.value = data;
      }
    }
    onChanged();
  }

  void fromUri(Uri uri) {
    final queryParameters = uri.queryParameters;
    filingJointly.value =
        queryParameters['filingJointly']?.toBoolean() ?? filingJointly.value;
    investmentTaxRate.value =
        queryParameters['investmentTaxRate']?.toDouble() ??
            investmentTaxRate.value;
    marginalTaxRate.value =
        queryParameters['marginalTaxRate']?.toDouble() ?? marginalTaxRate.value;
    vaLoan.value = queryParameters['vaLoan']?.toBoolean() ?? vaLoan.value;
    firstTimeHomebuyer.value =
        queryParameters['firstTimeHomebuyer']?.toBoolean() ??
            firstTimeHomebuyer.value;
    for (int i = 0; i < sliders.length; i++) {
      String key = sliders.keys.elementAt(i);
      final data = queryParameters[key]?.toDouble();
      if (data != null) {
        sliders[key]?.value = data;
      }
    }
    onChanged();
  }

  void reset() {
    filingJointly.value = false;
    vaLoan.value = false;
    firstTimeHomebuyer.value = true;
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
    await preferences.setBool("vaLoan", vaLoan.value);
    await preferences.setBool("firstTimeHomebuyer", firstTimeHomebuyer.value);
    for (int i = 0; i < sliders.length; i++) {
      String key = sliders.keys.elementAt(i);
      double value = sliders.values.elementAt(i).value;
      await preferences.setDouble(key, value);
    }
  }

  Uri toUri() {
    final Map<String, String> queryParameters = {};
    queryParameters["investmentTaxRate"] = investmentTaxRate.value.toString();
    queryParameters["marginalTaxRate"] = marginalTaxRate.value.toString();
    queryParameters["filingJointly"] = filingJointly.value.toString();
    queryParameters["vaLoan"] = vaLoan.value.toString();
    queryParameters["firstTimeHomebuyer"] = firstTimeHomebuyer.value.toString();
    for (int i = 0; i < sliders.length; i++) {
      String key = sliders.keys.elementAt(i);
      String value = sliders.values.elementAt(i).value.toString();
      queryParameters[key] = value;
    }
    final uri = Uri(queryParameters: queryParameters);
    return uri;
  }

  VoidCallback? copyUriClosure(BuildContext context) {
    void copyUri() async {
      final uri = toUri();
      final fullUrl = Uri.base.toString() + uri.toString();

      try {
        // Create shortened URL using TinyURL API
        final response = await http.get(
          Uri.parse(
              'https://tinyurl.com/api-create.php?url=${Uri.encodeComponent(fullUrl)}'),
        );

        if (response.statusCode == 200) {
          final shortenedUrl = response.body;
          await Clipboard.setData(ClipboardData(text: shortenedUrl));
        } else {
          // Fallback to original URL if shortening fails
          await Clipboard.setData(ClipboardData(text: fullUrl));
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("URL copied to clipboard")),
          );
        }
      } catch (e) {
        // Fallback to original URL if there's an error
        await Clipboard.setData(ClipboardData(text: fullUrl));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("URL copied to clipboard")),
          );
        }
      }
    }

    return copyUri;
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

  void copyCSV() async {
    final csv = createCSV();
    await Clipboard.setData(ClipboardData(text: csv));
  }

  void onInit(Uri uri) {
    if (uri.hasQuery) {
      fromUri(uri);
    } else {
      fromPreferences();
    }
  }

  DataFrame calculate() {
    return _calculate(
      filingJointly: filingJointly,
      vaLoan: vaLoan,
      firstTimeHomebuyer: firstTimeHomebuyer,
      investmentTaxRate: investmentTaxRate,
      marginalTaxRate: marginalTaxRate,
      sliders: sliders,
    );
  }

  static DataFrame _calculate({
    required SwitchData filingJointly,
    required SwitchData vaLoan,
    required SwitchData firstTimeHomebuyer,
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
      vaLoan: vaLoan.value,
      firstTimeHomebuyer: firstTimeHomebuyer.value,
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
    required SwitchData vaLoan,
    required SwitchData firstTimeHomebuyer,
    required RadioData investmentTaxRate,
    required RadioData marginalTaxRate,
    required Map<String, SliderData> sliders,
  }) {
    final maxLength = isWebMobile ? 40 : 80;
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
        vaLoan: vaLoan,
        firstTimeHomebuyer: firstTimeHomebuyer,
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
