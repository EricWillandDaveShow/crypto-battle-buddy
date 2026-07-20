enum FeedStatus {
  healthy,
  degraded,
  down,
  rateLimited,
}

class FeedHealth {
  final FeedStatus status;
  final DateTime timestamp;
  final String message;

  FeedHealth({
    required this.status,
    required this.timestamp,
    required this.message,
  });

  FeedHealth copyWith({
    FeedStatus? status,
    DateTime? timestamp,
    String? message,
  }) {
    return FeedHealth(
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      message: message ?? this.message,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'timestamp': timestamp.toIso8601String(),
        'message': message,
      };
}
