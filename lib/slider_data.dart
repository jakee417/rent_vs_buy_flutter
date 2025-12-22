import 'package:intl/intl.dart';
import 'package:finance_calculator/data.dart';

enum NumberType { dollar, percentage, decimal }

class SliderData implements Data {
  SliderData({
    this.prefix = "",
    required this.title,
    this.suffix = "",
    required this.value,
    required this.popoverDescription,
    required this.numberType,
    required this.min,
    required this.max,
    this.divisions = 100,
    this.suffixVariableMultiplier,
  }) : defaultValue = value;

  static const widthPercentage = 0.8;
  final String prefix;
  final String title;
  String suffix;
  @override
  double value;
  @override
  final String popoverDescription;
  @override
  final double defaultValue;
  final NumberType numberType;
  final double min;
  final double max;
  final int divisions;
  final String? suffixVariableMultiplier;

  String formatValue(double number) {
    switch (numberType) {
      case NumberType.dollar:
        return NumberFormat.compactSimpleCurrency().format(number);
      case NumberType.percentage:
        return NumberFormat.decimalPercentPattern(decimalDigits: 2)
            .format(number);
      case NumberType.decimal:
        return NumberFormat.decimalPattern().format(number);
    }
  }

  String get formattedValue {
    return formatValue(value);
  }

  String get formattedDefaultValue {
    return formatValue(defaultValue);
  }

  String get description => prefix + formattedValue + suffix;

  String computeHomeValueSuffix(double homePriceAmount, double percent) {
    if (suffixVariableMultiplier != null) {
      final dollarAmount = homePriceAmount * percent;
      return " ${NumberFormat.compactSimpleCurrency().format(dollarAmount)}";
    }
    return "";
  }

  SliderData copy() {
    return SliderData(
      title: title,
      value: value,
      popoverDescription: popoverDescription,
      numberType: numberType,
      min: min,
      max: max,
    );
  }
}
