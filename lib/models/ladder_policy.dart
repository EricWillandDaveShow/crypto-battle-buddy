enum LadderMode { equalSplit, weightProportional }

class LadderPolicy {
  final LadderMode mode;
  final double deployNowAmount;

  const LadderPolicy({
    required this.mode,
    required this.deployNowAmount,
  });
}
