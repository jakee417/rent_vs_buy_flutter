import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final isWebMobile = kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

class PieChartWidget extends StatefulWidget {
  PieChartWidget({
    super.key,
    required this.title,
    required this.ppmt,
    required this.ipmt,
    required this.taxes,
    required this.insurance,
    required this.hoa,
    required this.maintenance,
    required this.utilities,
    required this.pmi,
  });
  final String title;
  final List<double> ppmt;
  final List<double> ipmt;
  final List<double> taxes;
  final List<double> insurance;
  final List<double> hoa;
  final List<double> maintenance;
  final List<double> utilities;
  final List<double> pmi;

  @override
  State<PieChartWidget> createState() => _PieChartWidget();
}

class _PieChartWidget extends State<PieChartWidget> {
  final simpleCurrency = NumberFormat.simpleCurrency();
  final compactSimpleCurrency = NumberFormat.compactSimpleCurrency();
  int touchedIndex = 0;
  int timeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final infoButton = ElevatedButton(
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          builder: (BuildContext context) {
            return SizedBox(
              height: 250,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Spacer(),
                      const Text(
                        "Monthly Cost Breakdown",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      const Text(
                        """A breakdown of the monthly expenses over time.""",
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      ElevatedButton(
                        child: const Text("Done"),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
        fixedSize: const Size(10, 10),
      ),
      child: const Icon(Icons.info),
    );

    final totalPayment = widget.ppmt[timeIndex] +
        widget.ipmt[timeIndex] +
        widget.taxes[timeIndex] +
        widget.insurance[timeIndex] +
        widget.hoa[timeIndex] +
        widget.maintenance[timeIndex] +
        widget.utilities[timeIndex] +
        widget.pmi[timeIndex];

    final totalPaymentText = Text(
      "Payment: ${simpleCurrency.format(totalPayment)}",
      style: const TextStyle(fontSize: 24.0),
    );

    final slider = Slider(
      value: timeIndex as double,
      min: 0,
      max: widget.ppmt.length - 1 as double,
      divisions: widget.ppmt.length,
      onChangeStart: (value) {},
      onChanged: (value) {
        setState(
          () {
            timeIndex = value.round();
          },
        );
      },
      onChangeEnd: (value) {
        setState(
          () {
            timeIndex = value.round();
          },
        );
      },
      label: "Month ${timeIndex + 1}",
      thumbColor: Theme.of(context).colorScheme.onPrimaryContainer,
      inactiveColor: Theme.of(context).colorScheme.primaryContainer,
    );

    final description = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        totalPaymentText,
        Row(
          children: [
            const Icon(Icons.square, color: Colors.orange),
            Text("Interest: ${simpleCurrency.format(widget.ipmt[timeIndex])}")
          ],
        ),
        Row(
          children: [
            const Icon(Icons.square, color: Colors.blue),
            Text("Principal: ${simpleCurrency.format(widget.ppmt[timeIndex])}")
          ],
        ),
        Row(
          children: [
            const Icon(Icons.square, color: Colors.purple),
            Text("Taxes: ${simpleCurrency.format(widget.taxes[timeIndex])}")
          ],
        ),
        Row(
          children: [
            const Icon(Icons.square, color: Colors.green),
            Text(
                "Insurance: ${simpleCurrency.format(widget.insurance[timeIndex])}")
          ],
        ),
        Row(
          children: [
            const Icon(Icons.square, color: Colors.teal),
            Text(
                "Maintenance: ${simpleCurrency.format(widget.maintenance[timeIndex])}")
          ],
        ),
        Row(
          children: [
            const Icon(Icons.square, color: Colors.pink),
            Text(
                "Utilities: ${simpleCurrency.format(widget.utilities[timeIndex])}")
          ],
        ),
        Row(
          children: [
            const Icon(Icons.square, color: Colors.red),
            Text("HOA: ${simpleCurrency.format(widget.hoa[timeIndex])}")
          ],
        ),
        Row(
          children: [
            const Icon(Icons.square, color: Colors.yellow),
            Text("PMI: ${simpleCurrency.format(widget.pmi[timeIndex])}")
          ],
        ),
        Padding(padding: const EdgeInsets.only(top: 40), child: slider),
        const Text("Payment Month")
      ],
    );

    final pieChart = PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            setState(
              () {
                if (!event.isInterestedForInteractions ||
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) {
                  touchedIndex = -1;
                  return;
                }
                touchedIndex =
                    pieTouchResponse.touchedSection!.touchedSectionIndex;
              },
            );
          },
        ),
        borderData: FlBorderData(show: true),
        sectionsSpace: 0,
        centerSpaceRadius: 100,
        sections: showingSections(
          ppmt: widget.ppmt[timeIndex],
          ipmt: widget.ipmt[timeIndex],
          taxes: widget.taxes[timeIndex],
          insurance: widget.insurance[timeIndex],
          hoa: widget.hoa[timeIndex],
          maintenance: widget.maintenance[timeIndex],
          utilities: widget.utilities[timeIndex],
          pmi: widget.pmi[timeIndex],
        ),
      ),
    );

    final monthlyPayment = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: pieChart,
          ),
        ),
        description,
        const Spacer(),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.title),
            infoButton,
          ],
        ),
      ),
      body: Center(
          child: isWebMobile
              ? Padding(padding: const EdgeInsets.all(40), child: description)
              : monthlyPayment),
    );
  }

  List<PieChartSectionData> showingSections({
    required double ppmt,
    required double ipmt,
    required double taxes,
    required double insurance,
    required double hoa,
    required double maintenance,
    required double utilities,
    required double pmi,
  }) {
    return List.generate(8, (i) {
      final isTouched = i == touchedIndex;
      final fontSize = isTouched ? 20.0 : 16.0;
      final radius = isTouched ? 110.0 : 100.0;
      const shadows = [Shadow(color: Colors.black, blurRadius: 2)];

      switch (i) {
        case 0:
          return PieChartSectionData(
            color: Colors.blue,
            value: ppmt,
            title: "Principal\n${compactSimpleCurrency.format(ppmt)}",
            showTitle: isTouched,
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: const Color(0xffffffff),
              shadows: shadows,
            ),
          );
        case 1:
          return PieChartSectionData(
            color: Colors.orange,
            value: ipmt,
            title: "Interest\n${compactSimpleCurrency.format(ipmt)}",
            showTitle: isTouched,
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: shadows,
            ),
          );
        case 2:
          return PieChartSectionData(
            color: Colors.purple,
            value: taxes,
            title: "Taxes\n${compactSimpleCurrency.format(taxes)}",
            showTitle: isTouched,
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: shadows,
            ),
          );
        case 3:
          return PieChartSectionData(
            color: Colors.green,
            value: insurance,
            title: "Insurance\n${compactSimpleCurrency.format(insurance)}",
            showTitle: isTouched,
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: shadows,
            ),
          );
        case 4:
          return PieChartSectionData(
            color: Colors.red,
            value: hoa,
            title: "HOA\n${compactSimpleCurrency.format(hoa)}",
            showTitle: isTouched,
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: shadows,
            ),
          );
        case 5:
          return PieChartSectionData(
            color: Colors.teal,
            value: hoa,
            title: "Maintenance\n${compactSimpleCurrency.format(maintenance)}",
            showTitle: isTouched,
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: shadows,
            ),
          );
        case 6:
          return PieChartSectionData(
            color: Colors.pink,
            value: hoa,
            title: "Utilities\n${compactSimpleCurrency.format(utilities)}",
            showTitle: isTouched,
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: shadows,
            ),
          );
        case 7:
          return PieChartSectionData(
            color: Colors.yellow,
            value: hoa,
            title: "PMI\n${compactSimpleCurrency.format(pmi)}",
            showTitle: isTouched,
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: shadows,
            ),
          );
        default:
          throw Exception('Oh no');
      }
    });
  }
}
