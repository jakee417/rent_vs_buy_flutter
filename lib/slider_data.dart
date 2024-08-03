import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rent_vs_buy/data.dart';
import 'package:rent_vs_buy/thumb_shape.dart';

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
  }) : defaultValue = value;

  static const widthPercentage = 0.8;
  final String prefix;
  final String title;
  final String suffix;
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

  Widget getSlider({
    required BuildContext context,
    required void Function(double) onChanged,
  }) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        thumbShape: const ThumbShape(),
        valueIndicatorShape: SliderComponentShape.noOverlay,
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: 100,
        onChanged: onChanged,
        label: description,
        inactiveColor: Colors.deepOrangeAccent,
      ),
    );
  }

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
