class SellPlan {
  final Map<String, double> perAssetUsd;
  final double totalUsd;
  final String message;

  SellPlan({
    required this.perAssetUsd,
    required this.totalUsd,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'perAssetUsd': perAssetUsd,
        'totalUsd': totalUsd,
        'message': message,
      };
}
