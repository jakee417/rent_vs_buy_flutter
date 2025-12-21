import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:undo/undo.dart';
import 'refinance_manager.dart';

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
        title: const Text('Refinance Calculator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to Defaults',
            onPressed: () {
              context.read<RefinanceManager>().reset();
            },
          ),
        ],
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
                                  'This is your estimated monthly payment for the new refinanced loan, including principal and interest. This does not include property taxes, insurance, or HOA fees.\n\nNew payment: ${formatter.format(newMonthlyPayment)}\nCurrent payment: ${formatter.format(manager.currentMonthlyPayment)}\nMonthly difference: ${formatter.format(manager.calculateMonthlySavings())}',
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
    
    final description = """Refinancing from ${manager.currentInterestRate.toStringAsFixed(2)}% to ${manager.newInterestRate.toStringAsFixed(2)}%:

Current Loan:
  - Remaining Balance: ${formatter.format(manager.remainingBalance)}
  - Monthly Payment: ${formatter.format(manager.currentMonthlyPayment)}
  - Remaining Term: ${manager.remainingTermMonths} months

New Loan:
  - New Loan Amount: ${formatter.format(manager.calculateNewLoanAmount())}
  - New Monthly Payment: ${formatter.format(manager.calculateNewMonthlyPayment())}
  - Monthly Savings: ${formatter.format(monthlySavings)}
  - Upfront Costs: ${formatter.format(totalUpfront)}
  ${breakEven > 0 ? '- Break-Even: $breakEven months' : ''}
  - Opportunity Cost: ${formatter.format(opportunityCost)}
""";
    
    final bottomLine = "Total Savings: ${formatter.format(totalSavings)} (${totalSavings > 0 ? "benefit" : "loss"})";
    
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
  late TextEditingController _paymentController;
  double? _balanceOldValue;
  double? _paymentOldValue;
  late FocusNode _balanceFocusNode;
  late FocusNode _paymentFocusNode;

  @override
  void initState() {
    super.initState();
    _balanceController = TextEditingController();
    _paymentController = TextEditingController();
    _balanceFocusNode = FocusNode();
    _paymentFocusNode = FocusNode();
    
    _balanceFocusNode.addListener(_onBalanceFocusChange);
    _paymentFocusNode.addListener(_onPaymentFocusChange);
  }

  @override
  void dispose() {
    _balanceFocusNode.removeListener(_onBalanceFocusChange);
    _paymentFocusNode.removeListener(_onPaymentFocusChange);
    _balanceController.dispose();
    _paymentController.dispose();
    _balanceFocusNode.dispose();
    _paymentFocusNode.dispose();
    super.dispose();
  }

  void _onBalanceFocusChange() {
    final manager = context.read<RefinanceManager>();
    if (_balanceFocusNode.hasFocus) {
      // Started editing - capture old value
      _balanceOldValue = manager.remainingBalance;
    } else {
      // Finished editing - add undo change if value changed
      if (_balanceOldValue != null && _balanceOldValue != manager.remainingBalance) {
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
        manager.notifyListeners();
      }
      _balanceOldValue = null;
    }
  }

  void _onPaymentFocusChange() {
    final manager = context.read<RefinanceManager>();
    if (_paymentFocusNode.hasFocus) {
      // Started editing - capture old value
      _paymentOldValue = manager.currentMonthlyPayment;
    } else {
      // Finished editing - add undo change if value changed
      if (_paymentOldValue != null && _paymentOldValue != manager.currentMonthlyPayment) {
        final capturedOldValue = _paymentOldValue!;
        final capturedNewValue = manager.currentMonthlyPayment;
        manager.changes.add(
          Change(
            capturedOldValue,
            () {
              manager.currentMonthlyPayment = capturedNewValue;
              _paymentController.text = capturedNewValue.toString();
            },
            (old) {
              manager.currentMonthlyPayment = old;
              _paymentController.text = old.toString();
            },
          ),
        );
        manager.notifyListeners();
      }
      _paymentOldValue = null;
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
    if (!_paymentController.selection.isValid) {
      final paymentText = manager.currentMonthlyPayment.toString();
      if (_paymentController.text != paymentText) {
        _paymentController.text = paymentText;
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
                final cleanValue = value.replaceAll(',', '').replaceAll('\$', '').trim();
                final parsed = double.tryParse(cleanValue);
                if (parsed != null && parsed >= 0) {
                  final manager = context.read<RefinanceManager>();
                  manager.remainingBalance = parsed;
                }
              },
              prefix: '\$',
              description: 'The outstanding principal balance on your current mortgage loan. This is what you still owe, not the original loan amount.',
            ),
            const SizedBox(height: 12),
            _buildTextInputField(
              context: context,
              label: 'Current Monthly Payment',
              controller: _paymentController,
              focusNode: _paymentFocusNode,
              onChanged: (value) {
                final cleanValue = value.replaceAll(',', '').replaceAll('\$', '').trim();
                final parsed = double.tryParse(cleanValue);
                if (parsed != null && parsed >= 0) {
                  final manager = context.read<RefinanceManager>();
                  manager.currentMonthlyPayment = parsed;
                }
              },
              prefix: '\$',
              description: 'Your current monthly mortgage payment including principal and interest. Do not include property taxes, insurance, or HOA fees.',
            ),
            const SizedBox(height: 12),
            _buildInputFieldWithUndo(
              context: context,
              label: 'Current Interest Rate',
              value: context.watch<RefinanceManager>().currentInterestRate,
              onChanged: (value) =>
                  context.read<RefinanceManager>().currentInterestRate = value,
              suffix: '%',
              min: 0.1,
              max: 20.0,
              divisions: 199,
              description: 'The annual interest rate on your current mortgage loan. This is the APR (Annual Percentage Rate) on your existing loan.',
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
              description: 'The number of months remaining on your current mortgage. For example, if you have 25 years left on a 30-year loan, enter 300 months.',
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
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildInputFieldWithUndo({
    required BuildContext context,
    required String label,
    required double value,
    required Function(double) onChanged,
    String? prefix,
    String? suffix,
    required double min,
    required double max,
    int divisions = 100,
    String? description,
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
      buildInfoButton: description != null ? (ctx, title, desc) => _buildInfoButton(
        context: ctx,
        title: title,
        description: desc,
      ) : null,
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
  }) {
    return _UndoableIntSlider(
      label: label,
      value: value,
      onChanged: onChanged,
      min: min,
      max: max,
      description: description,
      buildInfoButton: description != null ? (ctx, title, desc) => _buildInfoButton(
        context: ctx,
        title: title,
        description: desc,
      ) : null,
    );
  }

  Widget _buildInfoButton({
    required BuildContext context,
    required String title,
    required String description,
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

class _NewLoanSection extends StatelessWidget {
  const _NewLoanSection();

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
              description: 'The length of the new mortgage in years. Common terms are 15 or 30 years. Shorter terms have higher monthly payments but lower total interest costs.',
            ),
            const SizedBox(height: 12),
            _buildInputFieldWithUndo(
              context: context,
              manager: manager,
              label: 'New Interest Rate',
              value: context.watch<RefinanceManager>().newInterestRate,
              onChanged: (value) => manager.newInterestRate = value,
              suffix: '%',
              min: 0.1,
              max: 20.0,
              divisions: 199,
              description: 'The annual interest rate for the new loan. Refinancing makes sense when this rate is significantly lower than your current rate (typically at least 0.5-1% lower).',
            ),
            const SizedBox(height: 12),
            _buildInputFieldWithUndo(
              context: context,
              manager: manager,
              label: 'Points',
              value: context.watch<RefinanceManager>().points,
              onChanged: (value) => manager.points = value,
              suffix: '%',
              min: 0.0,
              max: 5.0,
              divisions: 50,
              description: 'Discount points paid to reduce the interest rate. Each point equals 1% of the loan amount and typically reduces the rate by ~0.25%. Points are always paid upfront.',
            ),
            const SizedBox(height: 12),
            _buildInputFieldWithUndo(
              context: context,
              manager: manager,
              label: 'Costs and Fees',
              value: context.watch<RefinanceManager>().costsAndFees,
              onChanged: (value) => manager.costsAndFees = value,
              prefix: '\$',
              min: 0,
              max: 20000,
              divisions: 200,
              description: 'Closing costs including appraisal, title insurance, origination fees, etc. Typical refinance costs range from 2-5% of the loan amount. You can choose to finance these or pay upfront.',
            ),
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
              description: 'Additional cash you want to receive when refinancing (cash-out refinance). This amount is added to your new loan balance.',
            ),
            const SizedBox(height: 12),
            _buildInputFieldWithUndo(
              context: context,
              manager: manager,
              label: 'Additional Principal Payment',
              value: context.watch<RefinanceManager>().additionalPrincipalPayment,
              onChanged: (value) => manager.additionalPrincipalPayment = value,
              prefix: '\$',
              min: 0,
              max: 500000,
              divisions: 500,
              description: 'Extra principal you pay upfront when refinancing to reduce the new loan amount. This lowers your monthly payment and total interest, but has an opportunity cost since the money could be invested instead.',
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Finance Costs and Fees'),
              subtitle: Text(
                context.watch<RefinanceManager>().financeCosts
                    ? 'Costs will be added to loan principal'
                    : 'Costs will be paid upfront',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: context.watch<RefinanceManager>().financeCosts,
              onChanged: (value) {
                final oldValue = manager.financeCosts;
                manager.financeCosts = value;
                manager.changes.add(
                  Change(
                    oldValue,
                    () => manager.financeCosts = value,
                    (old) => manager.financeCosts = old,
                  ),
                );
                manager.notifyListeners();
              },
            ),
            const SizedBox(height: 12),
            _buildInputFieldWithUndo(
              context: context,
              manager: manager,
              label: 'Investment Return Rate (for opportunity cost)',
              value: context.watch<RefinanceManager>().investmentReturnRate,
              onChanged: (value) => manager.investmentReturnRate = value,
              suffix: '%',
              min: 0.0,
              max: 20.0,
              divisions: 200,
              description: 'The annual return rate you could earn by investing the upfront costs instead of paying them now. Used to calculate opportunity cost. Historical stock market average is around 7-10%.',
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Include Opportunity Cost in Total Savings'),
              subtitle: Text(
                context.watch<RefinanceManager>().includeOpportunityCost
                    ? 'Opportunity cost is included in calculations'
                    : 'Opportunity cost is excluded from calculations',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
                manager.notifyListeners();
              },
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
      buildInfoButton: description != null ? (ctx, title, desc) => _buildInfoButton(
        context: ctx,
        title: title,
        description: desc,
      ) : null,
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
  }) {
    return _UndoableIntSlider(
      label: label,
      value: value,
      onChanged: onChanged,
      min: min,
      max: max,
      description: description,
      buildInfoButton: description != null ? (ctx, title, desc) => _buildInfoButton(
        context: ctx,
        title: title,
        description: desc,
      ) : null,
    );
  }


  Widget _buildInfoButton({
    required BuildContext context,
    required String title,
    required String description,
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
              description: 'The estimated monthly payment for the new refinanced loan, including principal and interest.',
            ),
            _buildResultRow(
              context,
              'Monthly Savings',
              currencyFormat.format(monthlySavings),
              valueColor: monthlySavings > 0 ? Colors.green : Colors.red,
              description: 'The difference between your current monthly payment and the new monthly payment. Positive means you save money each month.',
            ),
            _buildResultRow(
              context,
              'Total Upfront Costs',
              currencyFormat.format(upfrontCosts),
              description: manager.additionalPrincipalPayment > 0
                  ? (manager.financeCosts
                      ? 'Includes ${currencyFormat.format(manager.additionalPrincipalPayment)} additional principal payment and points. Costs and fees are being added to the loan principal.'
                      : 'Includes ${currencyFormat.format(manager.additionalPrincipalPayment)} additional principal payment, plus points, costs, and fees.')
                  : (manager.financeCosts 
                      ? 'The upfront points cost. Costs and fees are being added to the loan principal.'
                      : 'The total amount you need to pay upfront, including points, costs, and fees.'),
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
                description: 'The time it will take for your monthly savings to offset the upfront costs of refinancing. After this point, you start seeing net savings.',
              )
            else if (breakEvenMonths == 0)
              _buildResultRow(
                context,
                'Break-Even Point',
                'Immediate',
                valueColor: Colors.green,
                description: 'Your monthly savings immediately offset the upfront costs of refinancing.',
              )
            else
              _buildResultRow(
                context,
                'Break-Even Point',
                'N/A (Higher monthly payment)',
                valueColor: Colors.red,
                description: 'Since your new monthly payment is higher, there is no break-even point based on monthly savings alone.',
              ),
            _buildResultRow(
              context,
              'Total Interest Saved',
              currencyFormat.format(totalSavings),
              valueColor: totalSavings > 0 ? Colors.green : Colors.red,
              description: 'The total amount of interest you will save (or pay extra if negative) over the life of the loan, including all costs and opportunity costs.',
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (widget.description != null && widget.buildInfoButton != null)
              widget.buildInfoButton!(context, widget.label, widget.description!)
            else
              Text(widget.label, style: const TextStyle(fontSize: 20)),
            Text(
              '${widget.prefix ?? ''}${widget.value.toStringAsFixed(widget.prefix != null ? 0 : 2)}${widget.suffix ?? ''}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        Slider(
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
              manager.notifyListeners();
            }
            _oldValue = null;
          },
        ),
      ],
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

  const _UndoableIntSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.description,
    this.buildInfoButton,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (widget.description != null && widget.buildInfoButton != null)
              widget.buildInfoButton!(context, widget.label, widget.description!)
            else
              Text(widget.label, style: const TextStyle(fontSize: 20)),
            Text(
              widget.value.toString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        Slider(
          value: widget.value.toDouble().clamp(widget.min.toDouble(), widget.max.toDouble()),
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
              manager.notifyListeners();
            }
            _oldValue = null;
          },
        ),
      ],
    );
  }
}
