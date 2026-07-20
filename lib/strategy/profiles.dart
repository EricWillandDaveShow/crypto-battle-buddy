import '../models/strategy_profile.dart';
import '../models/allocation_target.dart';
import '../models/ladder_policy.dart';
import '../models/sell_policy.dart';
import '../models/heat_mode.dart';

final StrategyProfile conservative = StrategyProfile(
  name: 'Conservative',
  targets: const [
    AllocationTarget(symbol: 'BTC', weight: 0.80),
    AllocationTarget(symbol: 'ETH', weight: 0.15),
    AllocationTarget(symbol: 'SOL', weight: 0.05),
  ],
  ladderPolicy: const LadderPolicy(
    mode: LadderMode.weightProportional,
    deployNowAmount: 150,
  ),
  sellPolicy: SellPolicy(fractionToSell: 0.30),
  heatConfig: HeatModeConfig(
    enabled: true,
    heatThresholdBySymbol: const <String, double>{},
  ),
  pollingInterval: const Duration(seconds: 45),
);

final StrategyProfile balanced = StrategyProfile(
  name: 'Balanced',
  targets: const [
    AllocationTarget(symbol: 'BTC', weight: 0.70),
    AllocationTarget(symbol: 'ETH', weight: 0.20),
    AllocationTarget(symbol: 'SOL', weight: 0.10),
  ],
  ladderPolicy: const LadderPolicy(
    mode: LadderMode.weightProportional,
    deployNowAmount: 200,
  ),
  sellPolicy: SellPolicy(fractionToSell: 0.25),
  heatConfig: HeatModeConfig(
    enabled: true,
    heatThresholdBySymbol: const <String, double>{},
  ),
  pollingInterval: const Duration(seconds: 30),
);

final StrategyProfile aggressive = StrategyProfile(
  name: 'Aggressive',
  targets: const [
    AllocationTarget(symbol: 'BTC', weight: 0.60),
    AllocationTarget(symbol: 'ETH', weight: 0.25),
    AllocationTarget(symbol: 'SOL', weight: 0.15),
  ],
  ladderPolicy: const LadderPolicy(
    mode: LadderMode.weightProportional,
    deployNowAmount: 250,
  ),
  sellPolicy: SellPolicy(fractionToSell: 0.20),
  heatConfig: HeatModeConfig(
    enabled: true,
    heatThresholdBySymbol: const <String, double>{},
  ),
  pollingInterval: const Duration(seconds: 20),
);

final List<StrategyProfile> allProfiles = [conservative, balanced, aggressive];
