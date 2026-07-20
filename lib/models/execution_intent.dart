import 'execution_mode.dart';

class ExecutionIntent {
  final ExecutionMode mode;
  final Map<String, double> perAssetAmounts;
  final DateTime timestamp;
  final String message;

  ExecutionIntent({
    required this.mode,
    required this.perAssetAmounts,
    required this.timestamp,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'timestamp': timestamp.toIso8601String(),
        'perAssetAmounts': perAssetAmounts,
        'message': message,
      };
}
