class StrategyReport {
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final String summary;

  StrategyReport({
    required this.timestamp,
    required this.data,
    required this.summary,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'summary': summary,
        'data': data,
      };
}
