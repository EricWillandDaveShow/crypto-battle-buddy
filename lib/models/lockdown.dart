class ReleaseChecklist {
  final bool reviewedZones;
  final bool reviewedBudget;
  final bool reviewedHeat;
  final bool reviewedExecutionMode;

  ReleaseChecklist({
    required this.reviewedZones,
    required this.reviewedBudget,
    required this.reviewedHeat,
    required this.reviewedExecutionMode,
  });

  bool get isComplete =>
      reviewedZones && reviewedBudget && reviewedHeat && reviewedExecutionMode;

  Map<String, dynamic> toJson() => {
        'reviewedZones': reviewedZones,
        'reviewedBudget': reviewedBudget,
        'reviewedHeat': reviewedHeat,
        'reviewedExecutionMode': reviewedExecutionMode,
      };

  static ReleaseChecklist fromJson(Map<String, dynamic> map) {
    return ReleaseChecklist(
      reviewedZones: map['reviewedZones'] == true,
      reviewedBudget: map['reviewedBudget'] == true,
      reviewedHeat: map['reviewedHeat'] == true,
      reviewedExecutionMode: map['reviewedExecutionMode'] == true,
    );
  }
}

class LockdownState {
  final bool enabled;
  final ReleaseChecklist checklist;

  LockdownState({required this.enabled, required this.checklist});

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'checklist': checklist.toJson(),
      };

  static LockdownState fromJson(Map<String, dynamic> map) {
    return LockdownState(
      enabled: map['enabled'] == true,
      checklist: ReleaseChecklist.fromJson(
        (map['checklist'] as Map<String, dynamic>? ?? {}),
      ),
    );
  }
}
