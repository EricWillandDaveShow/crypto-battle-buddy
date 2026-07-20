class DeploymentPlan {
  final Map<String, double> perAssetAmounts;
  final double totalToDeploy;
  final String message;

  const DeploymentPlan({
    required this.perAssetAmounts,
    required this.totalToDeploy,
    required this.message,
  });
}
