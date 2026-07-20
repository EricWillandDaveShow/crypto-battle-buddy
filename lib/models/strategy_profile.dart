import 'allocation_target.dart';
import 'ladder_policy.dart';
import 'sell_policy.dart';
import 'heat_mode.dart';

class StrategyProfile {
  final String name;
  final List<AllocationTarget> targets;
  final LadderPolicy ladderPolicy;
  final SellPolicy sellPolicy;
  final HeatModeConfig heatConfig;
  final Duration pollingInterval;

  StrategyProfile({
    required this.name,
    required this.targets,
    required this.ladderPolicy,
    required this.sellPolicy,
    required this.heatConfig,
    required this.pollingInterval,
  });
}
