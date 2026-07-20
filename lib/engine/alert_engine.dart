import '../models/status_snapshot.dart';
import '../models/alert_event.dart';
import '../models/cooldown_store.dart';
import '../core/portfolio_state.dart';

class AlertEngine {
  final CooldownStore cooldownStore;
  final Duration cooldown;

  AlertEngine({
    required this.cooldownStore,
    this.cooldown = const Duration(minutes: 30),
  });

  List<AlertEvent> evaluateAlerts(StatusSnapshot snapshot) {
    final alerts = <AlertEvent>[];

    for (final symbol in snapshot.decisions.keys) {
      final decision = snapshot.decisions[symbol]!;

      AlertType? type;
      if (decision.state == PortfolioState.buyZone) {
        type = AlertType.buyZone;
      } else if (decision.state == PortfolioState.sellZone) {
        type = AlertType.sellZone;
      } else {
        continue;
      }

      final key = '$symbol:${type.name}';
      final last = cooldownStore.lastFired(key);
      if (last != null && snapshot.timestamp.difference(last) < cooldown) {
        continue;
      }

      final metadata = {
        ...decision.metadata,
        'price': snapshot.prices[symbol],
      };

      final alert = AlertEvent(
        symbol: symbol,
        type: type,
        timestamp: snapshot.timestamp,
        message: decision.message,
        metadata: metadata,
      );

      cooldownStore.setLastFired(key, snapshot.timestamp);
      alerts.add(alert);
    }

    return alerts;
  }
}
