import 'package:flutter/material.dart';

class BudgetHeroCard extends StatelessWidget {
  final Color accentColor;
  final double budgetValue;
  final double minBudget;
  final double maxBudget;
  final ValueChanged<double> onBudgetChanged;
  final ValueChanged<double>? onBudgetChangeEnd;

  const BudgetHeroCard({
    super.key,
    this.accentColor = const Color(0xFF7DAAE8),
    required this.budgetValue,
    required this.minBudget,
    required this.maxBudget,
    required this.onBudgetChanged,
    this.onBudgetChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💸 Monthly Spend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '\$${budgetValue.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            label: 'Monthly spend',
            hint: 'Adjust your monthly spend limit',
            child: Slider(
              value: budgetValue.clamp(minBudget, maxBudget),
              min: minBudget,
              max: maxBudget,
              divisions: ((maxBudget - minBudget) / 25).round(),
              onChanged: onBudgetChanged,
              onChangeEnd: onBudgetChangeEnd,
              activeColor: accentColor,
              inactiveColor: accentColor.withOpacity(0.2),
              thumbColor: accentColor,
              semanticFormatterCallback: (double value) => 'Monthly spend \$${value.toStringAsFixed(0)}',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$300 still available',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }
}
