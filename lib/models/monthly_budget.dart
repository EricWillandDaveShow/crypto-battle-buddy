class MonthlyBudget {
  final double monthlyLimit;
  final double spentThisMonth;
  final DateTime month;

  const MonthlyBudget({
    required this.monthlyLimit,
    required this.spentThisMonth,
    required this.month,
  });

  double get remaining => (monthlyLimit - spentThisMonth).clamp(0, monthlyLimit);

  bool get isCurrentMonth {
    final now = DateTime.now();
    return now.year == month.year && now.month == month.month;
  }

  MonthlyBudget rolloverIfNeeded(DateTime now) {
    if (now.year != month.year || now.month != month.month) {
      return MonthlyBudget(
        monthlyLimit: monthlyLimit,
        spentThisMonth: 0,
        month: DateTime(now.year, now.month, 1),
      );
    }
    return this;
  }
}
