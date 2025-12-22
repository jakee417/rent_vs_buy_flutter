import 'package:finance_calculator/data.dart';

class RadioData implements Data {
  RadioData({
    required this.title,
    required this.value,
    required this.popoverDescription,
    required this.options,
  }) : defaultValue = value;

  final String title;
  @override
  double value;
  @override
  final String popoverDescription;
  @override
  final double defaultValue;
  List<double> options;
}
