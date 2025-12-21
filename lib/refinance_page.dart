import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
        final totalSavings = manager.calculateTotalCostDifference();
        final isAdvantageous = manager.isRefinanceAdvantageous();
        final formatter = NumberFormat.simpleCurrency();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outline,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Savings: ${formatter.format(totalSavings)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: totalSavings > 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    Text(
                      isAdvantageous ? 'Refinancing is advantageous' : 'Review carefully',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: !manager.changes.canUndo
                    ? null
                    : () {
                        manager.changes.undo();
                      },
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  fixedSize: const Size(40, 40),
                ),
                child: const Icon(
                  Icons.undo,
                  size: 20.0,
                  semanticLabel: "Undo the last action.",
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: !manager.changes.canRedo
                    ? null
                    : () {
                        manager.changes.redo();
                      },
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  fixedSize: const Size(40, 40),
                ),
                child: const Icon(
                  Icons.redo,
                  size: 20.0,
                  semanticLabel: "Redo the last action.",
                ),
              ),
            ],
          ),
        );
      },
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

  @override
  void initState() {
    super.initState();
    _balanceController = TextEditingController();
    _paymentController = TextEditingController();
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _paymentController.dispose();
    super.dispose();
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
              onChanged: (value) {
                final cleanValue = value.replaceAll(',', '').replaceAll('\$', '').trim();
                final parsed = double.tryParse(cleanValue);
                if (parsed != null && parsed >= 0) {
                  context.read<RefinanceManager>().remainingBalance = parsed;
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
              onChanged: (value) {
                final cleanValue = value.replaceAll(',', '').replaceAll('\$', '').trim();
                final parsed = double.tryParse(cleanValue);
                if (parsed != null && parsed >= 0) {
                  context.read<RefinanceManager>().currentMonthlyPayment = parsed;
                }
              },
              prefix: '\$',
              description: 'Your current monthly mortgage payment including principal and interest. Do not include property taxes, insurance, or HOA fees.',
            ),
            const SizedBox(height: 12),
            _buildInputField(
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
            _buildIntInputField(
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

  Widget _buildInputField({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (description != null)
              _buildInfoButton(
                context: context,
                title: label,
                description: description,
              )
            else
              Text(label, style: const TextStyle(fontSize: 20)),
            Text(
              '${prefix ?? ''}${value.toStringAsFixed(prefix != null ? 0 : 2)}${suffix ?? ''}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildIntInputField({
    required BuildContext context,
    required String label,
    required int value,
    required Function(int) onChanged,
    required int min,
    required int max,
    String? description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (description != null)
              _buildInfoButton(
                context: context,
                title: label,
                description: description,
              )
            else
              Text(label, style: const TextStyle(fontSize: 20)),
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
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
            _buildIntInputField(
              context: context,
              label: 'New Loan Term (years)',
              value: context.watch<RefinanceManager>().newLoanTermYears,
              onChanged: (value) =>
                  context.read<RefinanceManager>().newLoanTermYears = value,
              min: 10,
              max: 30,
              description: 'The length of the new mortgage in years. Common terms are 15 or 30 years. Shorter terms have higher monthly payments but lower total interest costs.',
            ),
            const SizedBox(height: 12),
            _buildInputField(
              context: context,
              label: 'New Interest Rate',
              value: context.watch<RefinanceManager>().newInterestRate,
              onChanged: (value) =>
                  context.read<RefinanceManager>().newInterestRate = value,
              suffix: '%',
              min: 0.1,
              max: 20.0,
              divisions: 199,
              description: 'The annual interest rate for the new loan. Refinancing makes sense when this rate is significantly lower than your current rate (typically at least 0.5-1% lower).',
            ),
            const SizedBox(height: 12),
            _buildInputField(
              context: context,
              label: 'Points',
              value: context.watch<RefinanceManager>().points,
              onChanged: (value) =>
                  context.read<RefinanceManager>().points = value,
              suffix: '%',
              min: 0.0,
              max: 5.0,
              divisions: 50,
              description: 'Discount points paid to reduce the interest rate. Each point equals 1% of the loan amount and typically reduces the rate by ~0.25%. Points are always paid upfront.',
            ),
            const SizedBox(height: 12),
            _buildInputField(
              context: context,
              label: 'Costs and Fees',
              value: context.watch<RefinanceManager>().costsAndFees,
              onChanged: (value) =>
                  context.read<RefinanceManager>().costsAndFees = value,
              prefix: '\$',
              min: 0,
              max: 20000,
              divisions: 200,
              description: 'Closing costs including appraisal, title insurance, origination fees, etc. Typical refinance costs range from 2-5% of the loan amount. You can choose to finance these or pay upfront.',
            ),
            const SizedBox(height: 12),
            _buildInputField(
              context: context,
              label: 'Cash Out Amount',
              value: context.watch<RefinanceManager>().cashOutAmount,
              onChanged: (value) =>
                  context.read<RefinanceManager>().cashOutAmount = value,
              prefix: '\$',
              min: 0,
              max: 100000,
              description: 'Additional cash you want to receive when refinancing (cash-out refinance). This amount is added to your new loan balance.',
            ),
            const SizedBox(height: 12),
            _buildInputField(
              context: context,
              label: 'Additional Principal Payment',
              value: context.watch<RefinanceManager>().additionalPrincipalPayment,
              onChanged: (value) =>
                  context.read<RefinanceManager>().additionalPrincipalPayment = value,
              prefix: '\$',
              min: 0,
              max: 100000,
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
              onChanged: (value) =>
                  context.read<RefinanceManager>().financeCosts = value,
            ),
            const SizedBox(height: 12),
            _buildInputField(
              context: context,
              label: 'Investment Return Rate (for opportunity cost)',
              value: context.watch<RefinanceManager>().investmentReturnRate,
              onChanged: (value) =>
                  context.read<RefinanceManager>().investmentReturnRate = value,
              suffix: '%',
              min: 0.0,
              max: 20.0,
              divisions: 200,
              description: 'The annual return rate you could earn by investing the upfront costs instead of paying them now. Used to calculate opportunity cost. Historical stock market average is around 7-10%.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (description != null)
              _buildInfoButton(
                context: context,
                title: label,
                description: description,
              )
            else
              Text(label, style: const TextStyle(fontSize: 20)),
            Text(
              '${prefix ?? ''}${value.toStringAsFixed(prefix != null ? 0 : 2)}${suffix ?? ''}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildIntInputField({
    required BuildContext context,
    required String label,
    required int value,
    required Function(int) onChanged,
    required int min,
    required int max,
    String? description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (description != null)
              _buildInfoButton(
                context: context,
                title: label,
                description: description,
              )
            else
              Text(label, style: const TextStyle(fontSize: 20)),
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
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
            const SizedBox(height: 16),
            Text(
              'Analysis:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _getAnalysisText(
                monthlySavings: monthlySavings,
                breakEvenMonths: breakEvenMonths,
                totalSavings: totalSavings,
                isAdvantageous: isAdvantageous,
              ),
              style: Theme.of(context).textTheme.bodyMedium,
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

  String _getAnalysisText({
    required double monthlySavings,
    required int breakEvenMonths,
    required double totalSavings,
    required bool isAdvantageous,
  }) {
    if (isAdvantageous) {
      if (monthlySavings > 0 && breakEvenMonths > 0) {
        return 'Refinancing appears to be a good option. You will save ${NumberFormat.simpleCurrency().format(monthlySavings)} per month and recoup your upfront costs in approximately ${(breakEvenMonths / 12).toStringAsFixed(1)} years. ';
      } else if (totalSavings > 0) {
        return 'While your monthly payment may increase, refinancing could save you ${NumberFormat.simpleCurrency().format(totalSavings)} in total interest over the life of the loan.';
      }
    } else {
      if (monthlySavings < 0) {
        return 'Your monthly payment would increase by ${NumberFormat.simpleCurrency().format(monthlySavings.abs())}, which may not be ideal. Consider if the other benefits outweigh this cost.';
      } else if (breakEvenMonths > 60) {
        return 'It would take over 5 years to break even on the upfront costs. Consider how long you plan to stay in the home.';
      }
    }
    return 'Review the numbers carefully to determine if refinancing makes sense for your situation. Consider factors like how long you plan to stay in the home and your financial goals.';
  }
}
