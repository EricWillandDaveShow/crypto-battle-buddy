class HeatModeConfig {
  final bool enabled;
  final Map<String, double> heatThresholdBySymbol;

  HeatModeConfig({
    required this.enabled,
    required this.heatThresholdBySymbol,
  });
}

class HeatModeState {
  final bool isHot;
  final String message;

  HeatModeState({
    required this.isHot,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'isHot': isHot,
        'message': message,
      };
}
