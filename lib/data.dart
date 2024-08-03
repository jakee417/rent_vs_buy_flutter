interface class Data {
  Data({
    required this.value,
    required this.popoverDescription,
  }) : defaultValue = value;
  double value;
  final String popoverDescription;
  final double defaultValue;
}
