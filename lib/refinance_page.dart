import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:undo/undo.dart';
import 'chart.dart';
import 'refinance_calculations.dart';
import 'refinance_manager.dart';
import 'thumb_shape.dart';
import 'rent_vs_buy_manager.dart';

class RefinancePage extends StatelessWidget {
  const RefinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final manager = RefinanceManager();
        manager.loadFromPreferences();
        return manager;
      },
      child: const RefinanceView(),
    );
  }
}

class RefinanceView extends StatelessWidget {
  const RefinanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Text("Refinance Calculator")],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: const Text(
                "Refinance Calculator",
                style: TextStyle(fontSize: 24),
              ),
            ),
            ListTile(
              title: const Text("Home"),
              leading: const Icon(
                Icons.home,
                size: 25.0,
                semanticLabel: "Go to home page.",
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/');
              },
            ),
            ListTile(
              title: const Text("Rent vs. Buy Calculator"),
              leading: const Icon(
                Icons.compare_arrows,
                size: 25.0,
                semanticLabel: "Open rent vs. buy calculator.",
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/rent-vs-buy');
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
                context.read<RefinanceManager>().reset();
              },
            )
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CurrentLoanSection(),
            SizedBox(height: 24),
            _NewLoanSection(),
            SizedBox(height: 24),
            _InvestmentSection(),
            SizedBox(height: 24),
            _HomeSaleSection(),
            SizedBox(height: 24),
            _ResultsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Consumer<RefinanceManager>(
      builder: (context, manager, child) {
        final newMonthlyPayment = manager.calculateNewMonthlyPayment();
        final formatter = NumberFormat.simpleCurrency();

        return BottomAppBar(
          child: Row(
            children: [
              _buildInfoButton(context: context, manager: manager),
              const SizedBox(width: 8),
              TextButton(
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
                                  "New Monthly Payment",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const Spacer(),
                                Text(
                                  'This is your estimated monthly payment for the new refinanced loan, including principal and interest. This does not include property taxes, insurance, or HOA fees.\n\nNew payment: ${formatter.format(newMonthlyPayment)}\nCurrent payment: ${formatter.format(manager.calculateCurrentMonthlyPayment())}\nMonthly difference: ${formatter.format(manager.calculateMonthlySavings())}',
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
                  '${NumberFormat.simpleCurrency(decimalDigits: 0).format(newMonthlyPayment)} / mo',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: !manager.changes.canUndo
                    ? null
                    : () {
                        manager.changes.undo();
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
              ElevatedButton(
                onPressed: !manager.changes.canRedo
                    ? null
                    : () {
                        manager.changes.redo();
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoButton({
    required BuildContext context,
    required RefinanceManager manager,
  }) {
    final formatter = NumberFormat.simpleCurrency();
    final totalSavings = manager.calculateTotalCostDifference();
    final monthlySavings = manager.calculateMonthlySavings();
    final breakEven = manager.calculateBreakEvenMonths();
    final totalUpfront = manager.calculateTotalUpfrontCosts();
    final opportunityCost = manager.calculateOpportunityCost();

    final description =
        """Refinancing from ${manager.currentInterestRate.toStringAsFixed(2)}% to ${manager.newInterestRate.toStringAsFixed(2)}%:

Current Loan:
  - Remaining Balance: ${formatter.format(manager.remainingBalance)}
  - Monthly Payment: ${formatter.format(manager.calculateCurrentMonthlyPayment())}
  - Remaining Term: ${manager.remainingTermMonths} months

New Loan:
  - New Loan Amount: ${formatter.format(manager.calculateNewLoanAmount())}
  - New Monthly Payment: ${formatter.format(manager.calculateNewMonthlyPayment())}
  - Nominal Interest Rate: ${manager.newInterestRate.toStringAsFixed(3)}%
  - APR (with fees): ${manager.calculateNewLoanAPR().toStringAsFixed(3)}%
  - Monthly Savings: ${formatter.format(monthlySavings)}
  - Upfront Costs: ${formatter.format(totalUpfront)}
  - Break-Even: $breakEven months
  - Opportunity Cost: ${formatter.format(opportunityCost)}
""";

    final bottomLine =
        "Total Savings: ${formatter.format(totalSavings)} (${totalSavings > 0 ? "benefit" : "loss"})";

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
                        "Refinance Analysis",
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
        NumberFormat.simpleCurrency(decimalDigits: 0).format(totalSavings),
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: totalSavings > 0.0 ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}

class _CurrentLoanSection extends StatefulWidget {
  const _CurrentLoanSection();

  @override
  State<_CurrentLoanSection> createState() => _CurrentLoanSectionState();
}

class _CurrentLoanSectionState extends State<_CurrentLoanSection> {
  late TextEditingController _balanceController;
  double? _balanceOldValue;
  late FocusNode _balanceFocusNode;

  late TextEditingController _currentInterestRateController;
  double? _currentInterestRateOldValue;
  late FocusNode _currentInterestRateFocusNode;

  @override
  void initState() {
    super.initState();
    _balanceController = TextEditingController();
    _balanceFocusNode = FocusNode();

    _currentInterestRateController = TextEditingController();
    _currentInterestRateFocusNode = FocusNode();

    _balanceFocusNode.addListener(_onBalanceFocusChange);
    _currentInterestRateFocusNode
        .addListener(_onCurrentInterestRateFocusChange);
  }

  @override
  void dispose() {
    _balanceFocusNode.removeListener(_onBalanceFocusChange);
    _balanceController.dispose();
    _balanceFocusNode.dispose();
    _currentInterestRateFocusNode
        .removeListener(_onCurrentInterestRateFocusChange);
    _currentInterestRateController.dispose();
    _currentInterestRateFocusNode.dispose();
    super.dispose();
  }

  void _onBalanceFocusChange() {
    final manager = context.read<RefinanceManager>();
    if (_balanceFocusNode.hasFocus) {
      // Started editing - capture old value
      _balanceOldValue = manager.remainingBalance;
    } else {
      // Finished editing - add undo change if value changed
      if (_balanceOldValue != null &&
          _balanceOldValue != manager.remainingBalance) {
        final capturedOldValue = _balanceOldValue!;
        final capturedNewValue = manager.remainingBalance;
        manager.changes.add(
          Change(
            capturedOldValue,
            () {
              manager.remainingBalance = capturedNewValue;
              _balanceController.text = capturedNewValue.toString();
            },
            (old) {
              manager.remainingBalance = old;
              _balanceController.text = old.toString();
            },
          ),
        );
      }
      _balanceOldValue = null;
    }
  }

  void _onCurrentInterestRateFocusChange() {
    final manager = context.read<RefinanceManager>();
    if (_currentInterestRateFocusNode.hasFocus) {
      // Started editing - capture old value
      _currentInterestRateOldValue = manager.currentInterestRate;
    } else {
      // Finished editing - add undo change if value changed
      if (_currentInterestRateOldValue != null &&
          _currentInterestRateOldValue != manager.currentInterestRate) {
        final capturedOldValue = _currentInterestRateOldValue!;
        final capturedNewValue = manager.currentInterestRate;
        manager.changes.add(
          Change(
            capturedOldValue,
            () {
              manager.currentInterestRate = capturedNewValue;
              _currentInterestRateController.text = capturedNewValue.toString();
            },
            (old) {
              manager.currentInterestRate = old;
              _currentInterestRateController.text = old.toString();
            },
          ),
        );
      }
      _currentInterestRateOldValue = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<RefinanceManager>();

    // Update controllers if values changed externally (only when not focused)
    if (!_balanceController.selection.isValid) {
      final balanceText = manager.remainingBalance.toString();
      if (_balanceController.text != balanceText) {
        _balanceController.text = balanceText;
      }
    }
    if (!_currentInterestRateController.selection.isValid) {
      final rateText = manager.currentInterestRate.toString();
      if (_currentInterestRateController.text != rateText) {
        _currentInterestRateController.text = rateText;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Loan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildTextInputField(
              context: context,
              label: 'Remaining Balance',
              controller: _balanceController,
              focusNode: _balanceFocusNode,
              onChanged: (value) {
                final cleanValue =
                    value.replaceAll(',', '').replaceAll('\$', '').trim();
                final parsed = double.tryParse(cleanValue);
                if (parsed != null && parsed >= 0) {
                  final manager = context.read<RefinanceManager>();
                  manager.remainingBalance = parsed;
                }
              },
              prefix: '\$',
              description:
                  'The outstanding principal balance on your current mortgage loan. This is what you still owe, not the original loan amount.',
            ),
            const SizedBox(height: 12),
            _buildTextInputField(
              context: context,
              label: 'Current Interest Rate',
              controller: _currentInterestRateController,
              focusNode: _currentInterestRateFocusNode,
              onChanged: (value) {
                final cleanValue = value.replaceAll('%', '').trim();
                final parsed = double.tryParse(cleanValue);
                if (parsed != null && parsed >= 0 && parsed <= 100) {
                  final manager = context.read<RefinanceManager>();
                  manager.currentInterestRate = parsed;
                }
              },
              suffix: '%',
              description:
                  'The fixed annual interest rate on your current mortgage loan (not APR). This is the nominal rate used to calculate your monthly payment, excluding fees and points which are handled separately.',
            ),
            const SizedBox(height: 12),
            _buildIntInputFieldWithUndo(
              context: context,
              label: 'Remaining Term (months)',
              value: context.watch<RefinanceManager>().remainingTermMonths,
              onChanged: (value) =>
                  context.read<RefinanceManager>().remainingTermMonths = value,
              min: 12,
              max: 360,
              description:
                  'The number of months remaining on your current mortgage. This also represents WHEN you choose to refinance - waiting longer means paying down more principal but paying more interest. The chart shows how timing affects total savings.',
              typicalValue: '240-300 months',
              variableName: 'remainingTermMonths',
            ),
            const SizedBox(height: 12),
            _buildReadOnlyField(
              context: context,
              label: 'Current Monthly Payment',
              value: NumberFormat.simpleCurrency()
                  .format(manager.calculateCurrentMonthlyPayment()),
              description:
                  'Your current monthly mortgage payment including principal and interest, calculated from your remaining balance, interest rate, and term. Does not include property taxes, insurance, or HOA fees.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInputField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required Function(String) onChanged,
    String? prefix,
    String? suffix,
    String? description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description != null)
          _buildInfoButton(
            context: context,
            title: label,
            description: description,
          )
        else
          Text(label, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: prefix,
            suffixText: suffix,
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required BuildContext context,
    required String label,
    required String value,
    String? description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description != null)
          _buildInfoButton(
            context: context,
            title: label,
            description: description,
          )
        else
          Text(label, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey.withOpacity(0.1),
          ),
          width: double.infinity,
          child: Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildIntInputFieldWithUndo({
    required BuildContext context,
    required String label,
    required int value,
    required Function(int) onChanged,
    required int min,
    required int max,
    String? description,
    String? typicalValue,
    String? variableName,
  }) {
    final manager = context.read<RefinanceManager>();
    return _UndoableIntSlider(
      label: label,
      value: value,
      onChanged: onChanged,
      min: min,
      max: max,
      description: description,
      buildInfoButton: description != null
          ? (ctx, title, desc) => _buildInfoButton(
                context: ctx,
                title: title,
                description: desc,
                typicalValue: typicalValue,
              )
          : null,
      variableName: variableName,
      manager: manager,
    );
  }

  Widget _buildInfoButton({
    required BuildContext context,
    required String title,
    required String description,
    String? typicalValue,
  }) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
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
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                      ),
                      if (typicalValue != null) ...[
                        const Spacer(),
                        Text(
                          '(typical value is $typicalValue)',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                      ],
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

class _NewLoanSection extends StatefulWidget {
  const _NewLoanSection();

  @override
  State<_NewLoanSection> createState() => _NewLoanSectionState();
}

class _NewLoanSectionState extends State<_NewLoanSection> {
  late TextEditingController _newInterestRateController;
  double? _newInterestRateOldValue;
  late FocusNode _newInterestRateFocusNode;

  late TextEditingController _pointsController;
  double? _pointsOldValue;
  late FocusNode _pointsFocusNode;

  @override
  void initState() {
    super.initState();
    _newInterestRateController = TextEditingController();
    _newInterestRateFocusNode = FocusNode();
    _newInterestRateFocusNode.addListener(_onNewInterestRateFocusChange);

    _pointsController = TextEditingController();
    _pointsFocusNode = FocusNode();
    _pointsFocusNode.addListener(_onPointsFocusChange);
  }

  @override
  void dispose() {
    _newInterestRateFocusNode.removeListener(_onNewInterestRateFocusChange);
    _newInterestRateController.dispose();
    _newInterestRateFocusNode.dispose();
    _pointsFocusNode.removeListener(_onPointsFocusChange);
    _pointsController.dispose();
    _pointsFocusNode.dispose();
    super.dispose();
  }

  void _onPointsFocusChange() {
    final manager = context.read<RefinanceManager>();
    if (_pointsFocusNode.hasFocus) {
      _pointsOldValue = manager.points;
    } else {
      if (_pointsOldValue != null && _pointsOldValue != manager.points) {
        final capturedOldValue = _pointsOldValue!;
        final capturedNewValue = manager.points;
        manager.changes.add(
          Change(
            capturedOldValue,
            () {
              manager.points = capturedNewValue;
              _pointsController.text = capturedNewValue.toString();
            },
            (old) {
              manager.points = old;
              _pointsController.text = old.toString();
            },
          ),
        );
      }
      _pointsOldValue = null;
    }
  }

  void _onNewInterestRateFocusChange() {
    final manager = context.read<RefinanceManager>();
    if (_newInterestRateFocusNode.hasFocus) {
      // Started editing - capture old value
      _newInterestRateOldValue = manager.newInterestRate;
    } else {
      // Finished editing - add undo change if value changed
      if (_newInterestRateOldValue != null &&
          _newInterestRateOldValue != manager.newInterestRate) {
        final capturedOldValue = _newInterestRateOldValue!;
        final capturedNewValue = manager.newInterestRate;
        manager.changes.add(
          Change(
            capturedOldValue,
            () {
              manager.newInterestRate = capturedNewValue;
              _newInterestRateController.text = capturedNewValue.toString();
            },
            (old) {
              manager.newInterestRate = old;
              _newInterestRateController.text = old.toString();
            },
          ),
        );
      }
      _newInterestRateOldValue = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.read<RefinanceManager>();

    // Update controller if value changed externally (only when not focused)
    if (!_newInterestRateController.selection.isValid) {
      final rateText =
          context.watch<RefinanceManager>().newInterestRate.toString();
      if (_newInterestRateController.text != rateText) {
        _newInterestRateController.text = rateText;
      }
    }
    if (!_pointsController.selection.isValid) {
      final pointsText = context.watch<RefinanceManager>().points.toString();
      if (_pointsController.text != pointsText) {
        _pointsController.text = pointsText;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Loan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildIntInputFieldWithUndo(
              context: context,
              manager: manager,
              label: 'New Loan Term (years)',
              value: context.watch<RefinanceManager>().newLoanTermYears,
              onChanged: (value) => manager.newLoanTermYears = value,
              min: 10,
              max: 30,
              description:
                  'The length of the new mortgage in years. Common terms are 15 or 30 years. Shorter terms have higher monthly payments but lower total interest costs.',
              typicalValue: '30 years',
              variableName: 'newLoanTermYears',
            ),
            const SizedBox(height: 12),
            _buildTextInputField(
              context: context,
              manager: manager,
              label: 'New Interest Rate',
              controller: _newInterestRateController,
              focusNode: _newInterestRateFocusNode,
              onChanged: (value) {
                final cleanValue = value.replaceAll('%', '').trim();
                final parsed = double.tryParse(cleanValue);
                if (parsed != null && parsed >= 0 && parsed <= 100) {
                  final manager = context.read<RefinanceManager>();
                  manager.newInterestRate = parsed;
                }
              },
              suffix: '%',
              description:
                  'The annual interest rate for the new loan. Refinancing makes sense when this rate is significantly lower than your current rate (typically at least 0.5-1% lower).',
              variableName: 'newInterestRate',
              chartMin: 0.1,
              chartMax: 20.0,
              chartDivisions: 199,
            ),
            const SizedBox(height: 12),
            _buildTextInputField(
              context: context,
              manager: manager,
              label: 'Points',
              controller: _pointsController,
              focusNode: _pointsFocusNode,
              onChanged: (value) {
                final cleanValue = value.replaceAll('%', '').trim();
                final parsed = double.tryParse(cleanValue);
                if (parsed != null && parsed >= 0 && parsed <= 100) {
                  final manager = context.read<RefinanceManager>();
                  manager.points = parsed;
                }
              },
              suffix: '%',
              description:
                  'Discount points paid to reduce the interest rate. Each point equals 1% of the loan amount and typically reduces the rate by ~0.25%. Points are always paid upfront.',
              variableName: 'points',
              chartMin: 0.0,
              chartMax: 5.0,
              chartDivisions: 50,
            ),
            const SizedBox(height: 12),
            _buildInputFieldWithUndo(
              context: context,
              manager: manager,
              label: 'Total Closing Fees',
              value: context.watch<RefinanceManager>().totalFees,
              onChanged: (value) => manager.totalFees = value,
              prefix: '\$',
              min: 0,
              max: 20000,
              divisions: 200,
              description:
                  'Total closing costs for the refinance. These include appraisal, title insurance, origination fees, and other lender charges. You can choose what percentage to finance vs pay upfront below.',
              typicalValue: '\$3,000-\$5,000',
              variableName: 'totalFees',
            ),
            const SizedBox(height: 12),
            _buildPercentageFinancedField(context, manager),
            const SizedBox(height: 12),
            _buildInputFieldWithUndo(
              context: context,
              manager: manager,
              label: 'Cash Out Amount',
              value: context.watch<RefinanceManager>().cashOutAmount,
              onChanged: (value) => manager.cashOutAmount = value,
              prefix: '\$',
              min: 0,
              max: 100000,
              description:
                  'Additional cash you want to receive when refinancing (cash-out refinance). This amount is added to your new loan balance.',
              typicalValue: '\$0',
              variableName: 'cashOutAmount',
            ),
            const SizedBox(height: 12),
            _buildInputFieldWithUndo(
              context: context,
              manager: manager,
              label: 'Additional Principal Payment',
              value:
                  context.watch<RefinanceManager>().additionalPrincipalPayment,
              onChanged: (value) => manager.additionalPrincipalPayment = value,
              prefix: '\$',
              min: 0,
              max: 500000,
              divisions: 500,
              description:
                  'Extra principal you pay upfront when refinancing to reduce the new loan amount. This lowers your monthly payment and total interest, but has an opportunity cost since the money could be invested instead.',
              typicalValue: '\$0',
              variableName: 'additionalPrincipalPayment',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputFieldWithUndo({
    required BuildContext context,
    required RefinanceManager manager,
    required String label,
    required double value,
    required Function(double) onChanged,
    String? prefix,
    String? suffix,
    required double min,
    required double max,
    int divisions = 100,
    String? description,
    String? typicalValue,
    String? variableName,
  }) {
    return _UndoableDoubleSlider(
      label: label,
      value: value,
      onChanged: onChanged,
      prefix: prefix,
      suffix: suffix,
      min: min,
      max: max,
      divisions: divisions,
      description: description,
      buildInfoButton: description != null
          ? (ctx, title, desc) => _buildInfoButton(
                context: ctx,
                title: title,
                description: desc,
                typicalValue: typicalValue,
              )
          : null,
      variableName: variableName,
      manager: manager,
    );
  }

  Widget _buildIntInputFieldWithUndo({
    required BuildContext context,
    required RefinanceManager manager,
    required String label,
    required int value,
    required Function(int) onChanged,
    required int min,
    required int max,
    String? description,
    String? typicalValue,
    String? variableName,
  }) {
    return _UndoableIntSlider(
      label: label,
      value: value,
      onChanged: onChanged,
      min: min,
      max: max,
      description: description,
      buildInfoButton: description != null
          ? (ctx, title, desc) => _buildInfoButton(
                context: ctx,
                title: title,
                description: desc,
                typicalValue: typicalValue,
              )
          : null,
      variableName: variableName,
      manager: manager,
    );
  }

  Widget _buildPercentageFinancedField(
      BuildContext context, RefinanceManager manager) {
    final percentageFinanced =
        context.watch<RefinanceManager>().percentageFinanced;
    final totalFees = context.watch<RefinanceManager>().totalFees;
    final financedAmount = totalFees * percentageFinanced;
    final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UndoableDoubleSlider(
          label: 'Percentage of Fees Financed',
          value: percentageFinanced,
          onChanged: (value) => manager.percentageFinanced = value,
          suffix: '%',
          min: 0,
          max: 1,
          divisions: 100,
          description:
              'The percentage of closing fees that will be added to your loan principal (financed). Financing fees increases your loan amount and total interest paid, but reduces upfront cash needed. Fees not financed are paid at closing.',
          buildInfoButton: (ctx, title, desc) => _buildInfoButton(
            context: ctx,
            title: title,
            description: desc,
            typicalValue: '100%',
          ),
          variableName: 'percentageFinanced',
          manager: manager,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.withOpacity(0.05),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Amount Financed:',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                currencyFormat.format(financedAmount),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.withOpacity(0.05),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Amount Paid Upfront:',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                currencyFormat.format(totalFees - financedAmount),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextInputField({
    required BuildContext context,
    required RefinanceManager manager,
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required Function(String) onChanged,
    String? prefix,
    String? suffix,
    String? description,
    String? variableName,
    double? chartMin,
    double? chartMax,
    int? chartDivisions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (description != null)
              _buildInfoButton(
                context: context,
                title: label,
                description: description,
              )
            else
              Text(label, style: const TextStyle(fontSize: 20)),
            if (variableName != null &&
                chartMin != null &&
                chartMax != null &&
                chartDivisions != null)
              _buildChartButton(
                context: context,
                label: label,
                variableName: variableName,
                manager: manager,
                min: chartMin,
                max: chartMax,
                divisions: chartDivisions,
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: prefix,
            suffixText: suffix,
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildChartButton({
    required BuildContext context,
    required String label,
    required String variableName,
    required RefinanceManager manager,
    required double min,
    required double max,
    required int divisions,
  }) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChartWidget(
              title: label,
              chartData: RefinanceManager.calculateChart(
                variableName: variableName,
                min: min,
                max: max,
                divisions: divisions,
                manager: manager,
              ),
              description:
                  "This chart shows how ${label.toLowerCase()} affects your total interest saved from refinancing.\n\nPositive values indicate you save money by refinancing. Negative values indicate refinancing would cost you more.",
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

  Widget _buildInfoButton({
    required BuildContext context,
    required String title,
    required String description,
    String? typicalValue,
  }) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
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
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                      ),
                      if (typicalValue != null) ...[
                        const Spacer(),
                        Text(
                          '(typical value is $typicalValue)',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                      ],
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

class _ResultsSection extends StatelessWidget {
  const _ResultsSection();

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<RefinanceManager>();
    final currencyFormat = NumberFormat.simpleCurrency();

    final newMonthlyPayment = manager.calculateNewMonthlyPayment();
    final monthlySavings = manager.calculateMonthlySavings();
    final upfrontCosts = manager.calculateTotalUpfrontCosts();
    final breakEvenMonths = manager.calculateBreakEvenMonths();
    final totalSavings = manager.calculateTotalCostDifference();
    final opportunityCost = manager.calculateOpportunityCost();
    final isAdvantageous = manager.isRefinanceAdvantageous();

    return Card(
      color: isAdvantageous
          ? Colors.green.withOpacity(0.1)
          : Colors.orange.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAdvantageous ? Icons.check_circle : Icons.warning,
                  color: isAdvantageous ? Colors.green : Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isAdvantageous
                        ? 'Refinancing Recommended'
                        : 'Refinancing May Not Be Advantageous',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: isAdvantageous ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildResultRow(
              context,
              'New Monthly Payment',
              currencyFormat.format(newMonthlyPayment),
              description:
                  'The estimated monthly payment for the new refinanced loan, including principal and interest. Disregards taxes, insurance, and HOA fees.',
            ),
            _buildResultRow(
              context,
              'Monthly Savings',
              currencyFormat.format(monthlySavings),
              valueColor: monthlySavings > 0 ? Colors.green : Colors.red,
              description:
                  'The difference between your current monthly payment and the new monthly payment. Positive means you save money each month.',
            ),
            _buildResultRow(
              context,
              'Total Upfront Costs',
              currencyFormat.format(upfrontCosts),
              description: manager.additionalPrincipalPayment > 0
                  ? 'Includes ${currencyFormat.format(manager.additionalPrincipalPayment)} additional principal payment, ${currencyFormat.format(manager.upfrontFees)} upfront fees, and points. The financed fees (${currencyFormat.format(manager.financedFees)}) are added to the loan principal.'
                  : (manager.upfrontFees > 0
                      ? 'Includes ${currencyFormat.format(manager.upfrontFees)} upfront fees and points. The financed fees (${currencyFormat.format(manager.financedFees)}) are added to the loan principal.'
                      : 'The upfront points cost. The financed fees (${currencyFormat.format(manager.financedFees)}) are added to the loan principal.'),
            ),
            if (opportunityCost > 0)
              _buildResultRow(
                context,
                'Opportunity Cost',
                currencyFormat.format(opportunityCost),
                subtitle: 'Lost investment growth from paying upfront',
                description: manager.additionalPrincipalPayment > 0
                    ? 'The potential investment returns you would have earned if you invested the upfront costs (including the additional principal payment) instead of paying them now, calculated over the life of the new loan at your specified investment return rate.'
                    : 'The potential investment returns you would have earned if you invested the upfront costs instead of paying them now, calculated over the life of the new loan at your specified investment return rate.',
              ),
            if (breakEvenMonths > 0)
              _buildResultRow(
                context,
                'Break-Even Point',
                '$breakEvenMonths months (${(breakEvenMonths / 12).toStringAsFixed(1)} years)',
                description:
                    'The time it will take for your monthly savings to offset the upfront costs of refinancing. After this point, you start seeing net savings.',
              )
            else if (breakEvenMonths == 0)
              _buildResultRow(
                context,
                'Break-Even Point',
                'Immediate',
                valueColor: Colors.green,
                description:
                    'Your monthly savings immediately offset the upfront costs of refinancing.',
              )
            else
              _buildResultRow(
                context,
                'Break-Even Point',
                'N/A (Higher monthly payment)',
                valueColor: Colors.red,
                description:
                    'Since your new monthly payment is higher, there is no break-even point based on monthly savings alone.',
              ),
            _buildResultRow(
              context,
              'Total Interest Saved',
              currencyFormat.format(totalSavings),
              valueColor: totalSavings > 0 ? Colors.green : Colors.red,
              description:
                  'The total amount of interest you will save (or pay extra if negative) over the life of the loan, including all costs and opportunity costs.',
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) =>
                        MonthlyBreakdownDialog(manager: manager),
                  );
                },
                icon: const Icon(Icons.table_chart),
                label: const Text('See Breakdown'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    String? subtitle,
    String? description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description != null)
                  _buildInfoButton(
                    context: context,
                    title: label,
                    description: description,
                  )
                else
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoButton({
    required BuildContext context,
    required String title,
    required String description,
    String? typicalValue,
  }) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
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
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                      ),
                      if (typicalValue != null) ...[
                        const Spacer(),
                        Text(
                          '(typical value is $typicalValue)',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}

// Stateful widget for double sliders with undo/redo support
class _UndoableDoubleSlider extends StatefulWidget {
  final String label;
  final double value;
  final Function(double) onChanged;
  final String? prefix;
  final String? suffix;
  final double min;
  final double max;
  final int divisions;
  final String? description;
  final Widget Function(BuildContext, String, String)? buildInfoButton;
  final String? variableName;
  final RefinanceManager? manager;

  const _UndoableDoubleSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.prefix,
    this.suffix,
    required this.min,
    required this.max,
    this.divisions = 100,
    this.description,
    this.buildInfoButton,
    this.variableName,
    this.manager,
  });

  @override
  State<_UndoableDoubleSlider> createState() => _UndoableDoubleSliderState();
}

class _UndoableDoubleSliderState extends State<_UndoableDoubleSlider> {
  double? _oldValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (widget.description != null && widget.buildInfoButton != null)
              widget.buildInfoButton!(
                  context, widget.label, widget.description!)
            else
              Text(widget.label, style: const TextStyle(fontSize: 20)),
            if (widget.variableName != null && widget.manager != null)
              _buildChartButton(context, widget.variableName!, widget.manager!),
          ],
        ),
        SizedBox(
          height: 120.0,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const ThumbShape(),
              valueIndicatorShape: SliderComponentShape.noOverlay,
              allowedInteraction: isWebMobile
                  ? SliderInteraction.slideOnly
                  : SliderInteraction.tapAndSlide,
            ),
            child: Slider(
              value: widget.value.clamp(widget.min, widget.max),
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              onChangeStart: (v) {
                _oldValue = widget.value;
              },
              onChanged: widget.onChanged,
              onChangeEnd: (newValue) {
                if (_oldValue != null && _oldValue != newValue) {
                  final manager = context.read<RefinanceManager>();
                  final capturedOldValue = _oldValue!;
                  manager.changes.add(
                    Change(
                      capturedOldValue,
                      () => widget.onChanged(newValue),
                      (old) => widget.onChanged(old),
                    ),
                  );
                }
                _oldValue = null;
              },
              label:
                  '${widget.prefix ?? ''}${widget.value.toStringAsFixed(widget.prefix != null ? 0 : 2)}${widget.suffix ?? ''}',
              thumbColor: Theme.of(context).colorScheme.onPrimaryContainer,
              inactiveColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartButton(
      BuildContext context, String variableName, RefinanceManager manager) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChartWidget(
              title: widget.label,
              chartData: RefinanceManager.calculateChart(
                variableName: variableName,
                min: widget.min,
                max: widget.max,
                divisions: widget.divisions,
                manager: manager,
              ),
              description:
                  "This chart shows how ${widget.label.toLowerCase()} affects your total interest saved from refinancing.\n\nPositive values indicate you save money by refinancing. Negative values indicate refinancing would cost you more.",
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
}

// Stateful widget for int sliders with undo/redo support
class _UndoableIntSlider extends StatefulWidget {
  final String label;
  final int value;
  final Function(int) onChanged;
  final int min;
  final int max;
  final String? description;
  final Widget Function(BuildContext, String, String)? buildInfoButton;
  final String? variableName;
  final RefinanceManager? manager;

  const _UndoableIntSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.description,
    this.buildInfoButton,
    this.variableName,
    this.manager,
  });

  @override
  State<_UndoableIntSlider> createState() => _UndoableIntSliderState();
}

class _UndoableIntSliderState extends State<_UndoableIntSlider> {
  int? _oldValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (widget.description != null && widget.buildInfoButton != null)
              widget.buildInfoButton!(
                  context, widget.label, widget.description!)
            else
              Text(widget.label, style: const TextStyle(fontSize: 20)),
            if (widget.variableName != null && widget.manager != null)
              _buildChartButton(context, widget.variableName!, widget.manager!),
          ],
        ),
        SizedBox(
          height: 120.0,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const ThumbShape(),
              valueIndicatorShape: SliderComponentShape.noOverlay,
              allowedInteraction: isWebMobile
                  ? SliderInteraction.slideOnly
                  : SliderInteraction.tapAndSlide,
            ),
            child: Slider(
              value: widget.value
                  .toDouble()
                  .clamp(widget.min.toDouble(), widget.max.toDouble()),
              min: widget.min.toDouble(),
              max: widget.max.toDouble(),
              divisions: widget.max - widget.min,
              onChangeStart: (v) {
                _oldValue = widget.value;
              },
              onChanged: (v) => widget.onChanged(v.round()),
              onChangeEnd: (v) {
                final newValue = v.round();
                if (_oldValue != null && _oldValue != newValue) {
                  final manager = context.read<RefinanceManager>();
                  final capturedOldValue = _oldValue!;
                  manager.changes.add(
                    Change(
                      capturedOldValue,
                      () => widget.onChanged(newValue),
                      (old) => widget.onChanged(old),
                    ),
                  );
                }
                _oldValue = null;
              },
              label: widget.value.toString(),
              thumbColor: Theme.of(context).colorScheme.onPrimaryContainer,
              inactiveColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartButton(
      BuildContext context, String variableName, RefinanceManager manager) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChartWidget(
              title: widget.label,
              chartData: RefinanceManager.calculateChart(
                variableName: variableName,
                min: widget.min.toDouble(),
                max: widget.max.toDouble(),
                divisions: widget.max - widget.min,
                manager: manager,
              ),
              description:
                  "This chart shows how ${widget.label.toLowerCase()} affects your total interest saved from refinancing.\n\nPositive values indicate you save money by refinancing. Negative values indicate refinancing would cost you more.",
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
}

// Widget to display month-by-month breakdown
class MonthlyBreakdownDialog extends StatefulWidget {
  final RefinanceManager manager;

  const MonthlyBreakdownDialog({super.key, required this.manager});

  @override
  State<MonthlyBreakdownDialog> createState() => _MonthlyBreakdownDialogState();
}

class _MonthlyBreakdownDialogState extends State<MonthlyBreakdownDialog> {
  List<MonthlyBreakdown>? _breakdown;
  bool _isLoading = true;
  final _headerController = ScrollController();
  final _bodyController = ScrollController();
  bool _isSyncing = false;
  static const double _rowHeight = 50.0;

  @override
  void initState() {
    super.initState();
    _headerController.addListener(_syncBodyToHeader);
    _bodyController.addListener(_syncHeaderToBody);
    _calculateBreakdown();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _syncBodyToHeader() {
    if (_isSyncing) return;
    _isSyncing = true;
    if (_bodyController.hasClients) {
      _bodyController.jumpTo(_headerController.offset);
    }
    _isSyncing = false;
  }

  void _syncHeaderToBody() {
    if (_isSyncing) return;
    _isSyncing = true;
    if (_headerController.hasClients) {
      _headerController.jumpTo(_bodyController.offset);
    }
    _isSyncing = false;
  }

  Future<void> _calculateBreakdown() async {
    // Give the UI time to render the loading indicator
    await Future.delayed(const Duration(milliseconds: 50));

    // Compute breakdown using async chunked calculation to avoid UI freeze
    final breakdown =
        await RefinanceCalculations.calculateMonthlyBreakdownAsync(
      remainingBalance: widget.manager.remainingBalance,
      remainingTermMonths: widget.manager.remainingTermMonths,
      currentInterestRate: widget.manager.currentInterestRate,
      newLoanTermYears: widget.manager.newLoanTermYears,
      newInterestRate: widget.manager.newInterestRate,
      points: widget.manager.points,
      financedFees: widget.manager.financedFees,
      upfrontFees: widget.manager.upfrontFees,
      cashOutAmount: widget.manager.cashOutAmount,
      additionalPrincipalPayment: widget.manager.additionalPrincipalPayment,
      investmentReturnRate: widget.manager.investmentReturnRate,
      includeOpportunityCost: widget.manager.includeOpportunityCost,
      monthsUntilSale: widget.manager.monthsUntilSale,
    );

    if (mounted) {
      setState(() {
        _breakdown = breakdown;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 800),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Month-by-Month Breakdown',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Loading or Table
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Calculating breakdown...'),
                        ],
                      ),
                    )
                  : _buildTable(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
    if (_breakdown == null) return const SizedBox();

    final currencyFormat = NumberFormat.simpleCurrency();

    return Column(
      children: [
        // Fixed header
        Container(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: SingleChildScrollView(
            controller: _headerController,
            scrollDirection: Axis.horizontal,
            child: _buildHeaderRow(context),
          ),
        ),
        const Divider(height: 1),
        // Scrollable body
        Expanded(
          child: SingleChildScrollView(
            controller: _bodyController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 800, // Total width of all columns
              child: ListView.builder(
                itemExtent: _rowHeight,
                itemCount: _breakdown!.length,
                itemBuilder: (context, index) {
                  final month = _breakdown![index];
                  final isCumulativePositive = month.cumulativeSavings >= 0;
                  final isMonthlySavingsPositive = month.monthlySavings >= 0;

                  return _buildDataRow(
                    context: context,
                    month: month,
                    currencyFormat: currencyFormat,
                    isCumulativePositive: isCumulativePositive,
                    isMonthlySavingsPositive: isMonthlySavingsPositive,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Row(
      children: [
        _buildHeaderCell('Month', 80),
        _buildHeaderCell('Current\nPayment', 120),
        _buildHeaderCell('Current\nBalance', 120),
        _buildHeaderCell('New\nPayment', 120),
        _buildHeaderCell('New\nBalance', 120),
        _buildHeaderCell('Monthly\nSavings', 120),
        _buildHeaderCell('Cumulative\nSavings', 120),
      ],
    );
  }

  Widget _buildHeaderCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDataRow({
    required BuildContext context,
    required MonthlyBreakdown month,
    required NumberFormat currencyFormat,
    required bool isCumulativePositive,
    required bool isMonthlySavingsPositive,
  }) {
    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildDataCell(month.month.toString(), 80),
          _buildDataCell(currencyFormat.format(month.currentLoanPayment), 120),
          _buildDataCell(currencyFormat.format(month.currentLoanBalance), 120),
          _buildDataCell(currencyFormat.format(month.newLoanPayment), 120),
          _buildDataCell(currencyFormat.format(month.newLoanBalance), 120),
          _buildDataCell(
            currencyFormat.format(month.monthlySavings),
            120,
            color: isMonthlySavingsPositive ? Colors.green : Colors.red,
          ),
          _buildDataCell(
            currencyFormat.format(month.cumulativeSavings),
            120,
            color: isCumulativePositive ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildDataCell(String text, double width, {Color? color}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _InvestmentSection extends StatelessWidget {
  const _InvestmentSection();

  @override
  Widget build(BuildContext context) {
    final manager = context.read<RefinanceManager>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Investment Assumptions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _UndoableDoubleSlider(
              label: 'Investment Return Rate',
              value: context.watch<RefinanceManager>().investmentReturnRate,
              onChanged: (value) => manager.investmentReturnRate = value,
              suffix: '%',
              min: 0.0,
              max: 20.0,
              divisions: 200,
              description:
                  'The annual return rate you could earn by investing the upfront costs instead of paying them now. Used to calculate opportunity cost. Historical stock market average is around 7-10%.',
              buildInfoButton: (ctx, title, desc) => _buildInfoButton(
                context: ctx,
                title: title,
                description: desc,
                typicalValue: '7%',
              ),
              variableName: 'investmentReturnRate',
              manager: manager,
            ),
            const SizedBox(height: 12),
            _buildSwitchField(
              context: context,
              manager: manager,
              title: 'Include Opportunity Cost',
              value: context.watch<RefinanceManager>().includeOpportunityCost,
              onChanged: (value) {
                final oldValue = manager.includeOpportunityCost;
                manager.includeOpportunityCost = value;
                manager.changes.add(
                  Change(
                    oldValue,
                    () => manager.includeOpportunityCost = value,
                    (old) => manager.includeOpportunityCost = old,
                  ),
                );
              },
              subtitle: null,
              description:
                  'When enabled, the total savings calculation includes the opportunity cost of money paid upfront. This represents the potential investment returns you give up by paying costs now instead of investing that money.',
              typicalValue: 'True',
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildInfoButton({
    required BuildContext context,
    required String title,
    required String description,
    String? typicalValue,
  }) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
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
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                      ),
                      if (typicalValue != null) ...[
                        const Spacer(),
                        Text(
                          '(typical value is $typicalValue)',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                      ],
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

  static Widget _buildSwitchField({
    required BuildContext context,
    required RefinanceManager manager,
    required String title,
    required bool value,
    required Function(bool) onChanged,
    String? subtitle,
    String? description,
    String? typicalValue,
  }) {
    final switchWidget = Switch(
      value: value,
      activeThumbColor: Theme.of(context).colorScheme.inversePrimary,
      onChanged: (bool newValue) {
        onChanged(newValue);
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            description != null
                ? _buildInfoButton(
                    context: context,
                    title: title,
                    description: description,
                    typicalValue: typicalValue,
                  )
                : Text(title, style: const TextStyle(fontSize: 20)),
          ],
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 12,
              ),
            ),
          ),
        SizedBox(
          height: 120.0,
          child: Row(
            children: [
              switchWidget,
              const Spacer(),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeSaleSection extends StatelessWidget {
  const _HomeSaleSection();

  @override
  Widget build(BuildContext context) {
    final manager = context.read<RefinanceManager>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Home Sale Timing',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _UndoableIntSlider(
              label: 'Months Until Home Sale',
              value: context.watch<RefinanceManager>().monthsUntilSale,
              onChanged: (value) =>
                  context.read<RefinanceManager>().monthsUntilSale = value,
              min: 1,
              max: 360,
              description:
                  'How many months from now you plan to sell your home. When you sell, you pay off the remaining loan balance. This helps you understand if you\'ll hold the home long enough to recoup refinancing costs through monthly payment savings.',
              buildInfoButton: (ctx, title, desc) => _buildInfoButton(
                context: ctx,
                title: title,
                description: desc,
                typicalValue: '120 months (10 years)',
              ),
              variableName: 'monthsUntilSale',
              manager: manager,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoButton({
    required BuildContext context,
    required String title,
    required String description,
    String? typicalValue,
  }) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
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
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                      ),
                      if (typicalValue != null) ...[
                        const Spacer(),
                        Text(
                          '(typical value is $typicalValue)',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
