enum ThresholdStepStatus {
  pending,
  seen,
  dismissed,
  executed,
}

class ThresholdStepState {
  final String stepId;
  final ThresholdStepStatus status;
  final DateTime updatedAt;
  bool wasTriggered;
  bool wasCompleted;

  ThresholdStepState({
    required this.stepId,
    required this.status,
    required this.updatedAt,
    this.wasTriggered = false,
    this.wasCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'stepId': stepId,
      'status': status.name,
      'updatedAt': updatedAt.toIso8601String(),
      'wasTriggered': wasTriggered,
      'wasCompleted': wasCompleted,
    };
  }

  static ThresholdStepState fromJson(
    Map<String, dynamic> json,
    String stepId,
  ) {
    try {
      final statusStr = json['status'] as String?;
      final updatedAtStr = json['updatedAt'] as String?;

      final status = ThresholdStepStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => ThresholdStepStatus.pending,
      );

      final updatedAt = updatedAtStr != null
          ? DateTime.parse(updatedAtStr)
          : DateTime.fromMillisecondsSinceEpoch(0);

      return ThresholdStepState(
        stepId: stepId,
        status: status,
        updatedAt: updatedAt,
        wasTriggered: json['wasTriggered'] == true,
        wasCompleted: json['wasCompleted'] == true,
      );
    } catch (_) {
      return ThresholdStepState(
        stepId: stepId,
        status: ThresholdStepStatus.pending,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }
  }
}
