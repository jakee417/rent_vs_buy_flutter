import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rent_vs_buy/chart.dart';
import 'package:rent_vs_buy/pie_chart.dart';
import 'package:rent_vs_buy/radio_data.dart';
import 'package:rent_vs_buy/rent_vs_buy_manager.dart';
import 'package:rent_vs_buy/slider_data.dart';
import 'package:rent_vs_buy/switch_data.dart';
import 'package:rent_vs_buy/thumb_shape.dart';
import 'package:undo/undo.dart';

final isWebMobile = kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

void main() {
  var rentVsBuyManager = RentVsBuyManager();
  rentVsBuyManager.onInit();
  runApp(ChangeNotifierProvider(
    create: (context) => rentVsBuyManager,
    child: const RentVsBuyWidget(),
  ));
}

class RentVsBuyWidget extends StatelessWidget {
  const RentVsBuyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rent vs. Buy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const Sliders(title: 'Rent vs. Buy Calculator'),
    );
  }
}

class Sliders extends StatefulWidget {
  const Sliders({super.key, required this.title});
  final String title;

  @override
  State<Sliders> createState() => _Sliders();
}

class _Sliders extends State<Sliders> {
  static const widthPercentage = 0.9;
  static const rowHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    var manager = context.read<RentVsBuyManager>();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Text(widget.title), getPieChartButton(manager: manager)],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: getDrawerItems(manager: manager),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 5,
          horizontal: 20.0,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            ...getSliders(
              context: context,
              sliders: Map.fromEntries(
                manager.sliders.entries.where(
                  (k) => manager.requiredSliders.contains(k.key),
                ),
              ),
              manager: manager,
            ),
            ExpansionTile(
              title: const Text("Show More"),
              children: [
                getSwitch(
                  data: manager.filingJointly,
                  manager: manager,
                ),
                getRadio(
                  data: manager.investmentTaxRate,
                  manager: manager,
                ),
                getRadio(
                  data: manager.marginalTaxRate,
                  manager: manager,
                ),
                ...getSliders(
                  context: context,
                  sliders: Map.fromEntries(
                    manager.sliders.entries.where(
                      (k) => !manager.requiredSliders.contains(k.key),
                    ),
                  ),
                  manager: manager,
                )
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          children: getBottomNavigationBarChildren(),
        ),
      ),
    );
  }

  Column getSwitch({
    required SwitchData data,
    required RentVsBuyManager manager,
  }) {
    Switch switchWidget = Switch(
      value: data.value,
      activeColor: Theme.of(context).colorScheme.inversePrimary,
      onChanged: (bool value) {
        setState(
          () {
            manager.changes.add(
              Change(
                data.value,
                () {
                  data.value = value;
                  manager.onChanged();
                  manager.onChangeEnd();
                },
                (oldValue) {
                  data.value = oldValue;
                  manager.onChanged();
                  manager.onChangeEnd();
                },
              ),
            );
          },
        );
      },
    );
    final switchRow = Row(
      children: [
        switchWidget,
        const Spacer(),
      ],
    );
    return Column(
      children: [
        Row(
          children: [
            getTitle(
              title: data.title,
              popoverDescription: data.popoverDescription,
              defaultValue: "True",
            ),
            const Spacer()
          ],
        ),
        SizedBox(
          height: rowHeight,
          width: MediaQuery.of(context).size.width * widthPercentage,
          child: switchRow,
        ),
      ],
    );
  }

  Column getRadio({
    required RadioData data,
    required RentVsBuyManager manager,
  }) {
    const spacer = SizedBox(width: 5);
    List<Widget> children = [];
    for (var option in data.options) {
      children.add(
        Radio<double>(
          value: option,
          groupValue: data.value,
          onChanged: (double? value) {
            if (value != null) {
              setState(
                () {
                  manager.changes.add(
                    Change(
                      data.value,
                      () {
                        data.value = value;
                        manager.onChanged();
                        manager.onChangeEnd();
                      },
                      (oldValue) {
                        data.value = oldValue;
                        manager.onChanged();
                        manager.onChangeEnd();
                      },
                    ),
                  );
                },
              );
            }
          },
        ),
      );
      children.add(
        Text(
          NumberFormat.decimalPercentPattern(decimalDigits: 0).format(option),
          style: const TextStyle(fontSize: 20),
        ),
      );
      children.add(
        spacer,
      );
    }
    return Column(
      children: [
        Row(
          children: [
            getTitle(
              title: data.title,
              popoverDescription: data.popoverDescription,
              defaultValue:
                  NumberFormat.percentPattern().format(data.defaultValue),
            ),
            spacer,
          ],
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width * widthPercentage,
          height: rowHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: children),
          ),
        ),
      ],
    );
  }

  Widget getTitle({
    required String title,
    required String popoverDescription,
    required String defaultValue,
  }) {
    return BottomInfoSheet(
      title: title,
      description: popoverDescription,
      defaultValue: defaultValue,
    );
  }

  ElevatedButton getPieChartButton({
    required RentVsBuyManager manager,
  }) {
    return ElevatedButton(
      onPressed: () {
        final result = manager.calculate();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PieChartWidget(
              title: "Monthly cost breakdown",
              ppmt: result["ppmt"].data.map((i) => i as double).toList(),
              ipmt: result["ipmt"].data.map((i) => i as double).toList(),
              taxes: result["propertyTaxes"].data.map((i) => i as double).toList(),
              insurance: result["insurance"].data.map((i) => i as double).toList(),
              hoa: result["monthlyCommonFees"].data.map((i) => i as double).toList(),
              maintenance: result["maintenance"].data.map((i) => i as double).toList(),
              utilities: result["homeMonthlyUtilities"].data.map((i) => i as double).toList(),
              pmi: result["pmi"].data.map((i) => i as double).toList(),
            ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
        fixedSize: const Size(10, 10),
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        foregroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      child: const Icon(
        Icons.pie_chart_outline_outlined,
        size: 25.0,
        semanticLabel: "See pie chart of monthly expenses.",
      ),
    );
  }

  ElevatedButton getChartButton({
    required String key,
    required SliderData data,
    required RentVsBuyManager manager,
  }) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChartWidget(
              title: data.title,
              chartData: RentVsBuyManager.calculateChart(
                key: key,
                data: data,
                filingJointly: manager.filingJointly,
                investmentTaxRate: manager.investmentTaxRate,
                marginalTaxRate: manager.marginalTaxRate,
                sliders: manager.sliders,
              ),
            ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
        fixedSize: const Size(10, 10),
      ),
      child: const Icon(
        Icons.auto_graph_sharp,
        size: 25.0,
        semanticLabel: "See graph of marginal values.",
      ),
    );
  }

  Widget getSlider({
    required SliderData data,
  }) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        thumbShape: const ThumbShape(),
        valueIndicatorShape: SliderComponentShape.noOverlay,
        allowedInteraction: isWebMobile
            ? SliderInteraction.slideOnly
            : SliderInteraction.tapAndSlide,
      ),
      child: Knob(data: data),
    );
  }

  Widget getInfoButton({required RentVsBuyManager manager}) {
    final formatter = NumberFormat.compactSimpleCurrency();
    final description =
        """Purchasing a home for ${manager.sliders["homePriceAmount"]?.formattedValue} your breakdown over ${manager.sliders["years"]?.formattedValue} years will be:
  - total home assets: ${formatter.format(manager.totalHomeAssetsCumulative)}
  - total home cost: ${formatter.format(manager.totalHomeLiabilityCumulative)}
  - total home profit: ${formatter.format(manager.totalHomeAssetsCumulative - manager.totalHomeLiabilityCumulative)}
  - home opportunity cost: ${formatter.format(manager.homeCumulativeOpportunity)} (${manager.sliders["investmentReturnRate"]?.formattedValue} investment return rate)
  
The rent breakdown will be:
  - total rental assets: ${formatter.format(manager.totalRentAssetsCumulative)} 
  - total rental cost: ${formatter.format(manager.totalRentLiabilityCumulative)}
  - total rental profit: ${formatter.format(manager.totalRentAssetsCumulative - manager.totalRentLiabilityCumulative)} 
  - rental opportunity cost: ${formatter.format(manager.rentalCumulativeOpportunity)} (${manager.sliders["homePriceGrowthRate"]?.formattedValue} home price growth rate)
""";
    final bottomLine =
        "Rental - Home opportunity cost: ${NumberFormat.simpleCurrency().format(manager.rentVsBuyValue)} (${manager.rentVsBuyValue > 0 ? "benefit" : "loss"})";
    return TextButton(
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) {
            return SizedBox(
              height: 500,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Spacer(),
                      const Text(
                        "Rent vs. Buy Result",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      Text(
                        description,
                        textAlign: TextAlign.left,
                      ),
                      Text(
                        bottomLine,
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
      child: Text(
        NumberFormat.simpleCurrency(decimalDigits: 0)
            .format(manager.rentVsBuyValue),
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: manager.rentVsBuyValue > 0.0 ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  List<Widget> getBottomNavigationBarChildren() {
    return [
      Consumer<RentVsBuyManager>(
        builder: (context, value, child) => getInfoButton(manager: value),
      ),
      const Spacer(),
      Consumer<RentVsBuyManager>(
        builder: (context, value, child) => ElevatedButton(
          onPressed: !value.changes.canUndo
              ? null
              : () {
                  if (mounted) {
                    setState(
                      () {
                        value.changes.undo();
                      },
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            fixedSize: const Size(10, 10),
          ),
          child: const Icon(
            Icons.undo,
            size: 25.0,
            semanticLabel: "Undo the last action.",
          ),
        ),
      ),
      Consumer<RentVsBuyManager>(
        builder: (context, value, child) => ElevatedButton(
          onPressed: !value.changes.canRedo
              ? null
              : () {
                  if (mounted) {
                    setState(
                      () {
                        value.changes.redo();
                      },
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            fixedSize: const Size(10, 10),
          ),
          child: const Icon(
            Icons.redo,
            size: 25.0,
            semanticLabel: "Redo the last action.",
          ),
        ),
      ),
    ];
  }

  List<Widget> getDrawerItems({required RentVsBuyManager manager}) {
    return [
      DrawerHeader(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
        child: const Text(
          "Rent vs. Buy",
          style: TextStyle(fontSize: 24),
        ),
      ),
      ListTile(
        title: const Text("Copy to CSV"),
        leading: const Icon(
          Icons.copy,
          size: 25.0,
          semanticLabel: "Copy a monthly breakdown of cashflows.",
        ),
        onTap: () {
          manager.copy();
          Navigator.pop(context);
        },
      ),
      ListTile(
        title: const Text("Reset to Defaults"),
        leading: const Icon(
          Icons.restore,
          size: 25.0,
          semanticLabel: "Reset all options.",
        ),
        onTap: () {
          setState(
            () {
              manager.reset();
              manager.onChanged();
              manager.onChangeEnd();
              Navigator.pop(context);
            },
          );
        },
      )
    ];
  }

  List<Widget> getSliders({
    required BuildContext context,
    required Map<String, SliderData> sliders,
    required RentVsBuyManager manager,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    List<Widget> result = [];
    for (int i = 0; i < sliders.length; i++) {
      String key = sliders.keys.elementAt(i);
      SliderData value = sliders.values.elementAt(i);
      final slider = getSlider(data: value);
      final title = getTitle(
        title: value.title,
        popoverDescription: value.popoverDescription,
        defaultValue: value.formattedDefaultValue,
      );
      final header = Row(
        children: [
          title,
          getChartButton(
            key: key,
            data: value,
            manager: manager,
          ),
          const Spacer(),
        ],
      );
      final column = Column(
        children: [
          header,
          SizedBox(
            height: rowHeight,
            width: width * widthPercentage,
            child: slider,
          ),
        ],
      );
      result.add(column);
    }
    return result;
  }
}

class Knob extends StatefulWidget {
  const Knob({super.key, required this.data});

  final SliderData data;

  @override
  State<Knob> createState() => _Knob();
}

class _Knob extends State<Knob> {
  double _value = 0.0;

  @override
  Widget build(BuildContext context) {
    var manager = context.read<RentVsBuyManager>();
    return Slider(
      value: widget.data.value,
      min: widget.data.min,
      max: widget.data.max,
      divisions: widget.data.divisions,
      onChangeStart: (value) {
        _value = widget.data.value;
      },
      onChanged: (value) {
        setState(
          () {
            widget.data.value = value;
            final suffixVariableMultiplier =
                widget.data.suffixVariableMultiplier;
            if (suffixVariableMultiplier != null) {
              final suffixValue =
                  manager.suffixMultiplier(suffixVariableMultiplier);
              widget.data.suffix =
                  widget.data.computeHomeValueSuffix(suffixValue, value);
            }
            manager.onChanged();
          },
        );
      },
      onChangeEnd: (value) {
        setState(
          () {
            widget.data.suffix = "";
            manager.changes.add(
              Change(
                _value,
                () {
                  widget.data.value = value;
                  manager.onChanged();
                  manager.onChangeEnd();
                },
                (oldValue) {
                  widget.data.value = oldValue;
                  manager.onChanged();
                  manager.onChangeEnd();
                },
              ),
            );
          },
        );
      },
      label: widget.data.description,
      thumbColor: Theme.of(context).colorScheme.onPrimaryContainer,
      inactiveColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }
}

class BottomInfoSheet extends StatelessWidget {
  const BottomInfoSheet({
    super.key,
    required this.title,
    required this.description,
    required this.defaultValue,
  });

  final String title;
  final String description;
  final String defaultValue;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(),
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
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      Text(
                        "(typical value is $defaultValue)",
                        style: const TextStyle(fontStyle: FontStyle.italic),
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
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
        ),
      ),
    );
  }
}
