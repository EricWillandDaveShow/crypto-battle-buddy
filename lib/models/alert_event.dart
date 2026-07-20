enum AlertType { buyZone, sellZone }

class AlertEvent {
  final String symbol;
  final AlertType type;
  final DateTime timestamp;
  final String message;
  final Map<String, dynamic> metadata;

  const AlertEvent({
    required this.symbol,
    required this.type,
    required this.timestamp,
    required this.message,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'message': message,
      'metadata': metadata,
    };
  }
}
