import 'package:rent_vs_buy/rent_vs_buy.dart';

void main() {
  final stopwatch = Stopwatch()..start();
  final df = RentVsBuy.calculate(homePriceAmount: 15000000);
  print(df.toString());
  print('executed in ${stopwatch.elapsed.inMilliseconds}(ms)');
}
