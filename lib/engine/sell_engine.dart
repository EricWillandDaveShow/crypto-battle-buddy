import '../models/alert_event.dart';
import '../models/position.dart';
import '../models/sell_policy.dart';
import '../models/sell_plan.dart';

class SellEngine {
  SellPlan build({
    required List<AlertEvent> alerts,
    required Map<String, Position> positions,
    required Map<String, double> prices,
    required SellPolicy policy,
  }) {
    final triggered = alerts.where((a) => a.type == AlertType.sellZone).map((a) => a.symbol).toSet();

    if (triggered.isEmpty) {
      return SellPlan(perAssetUsd: {}, totalUsd: 0, message: 'No profit alerts. No profit plan.');
    }

    final Map<String, double> per = {};
    double total = 0.0;

    for (final sym in triggered) {
      final pos = positions[sym];
      final price = prices[sym];
      if (pos == null || price == null) continue;
      if (pos.units <= 0 || price <= 0) continue;

      final usd = (pos.units * price * policy.fractionToSell);
      final rounded = double.parse(usd.toStringAsFixed(2));
      if (rounded <= 0) continue;

      per[sym] = rounded;
      total += rounded;
    }

    total = double.parse(total.toStringAsFixed(2));

    return SellPlan(
      perAssetUsd: per,
      totalUsd: total,
      message: total > 0 ? 'Profit plan created from profit alerts.' : 'No sellable positions.',
    );
  }
}
