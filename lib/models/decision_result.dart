import '../core/portfolio_state.dart';

class DecisionResult {
  final PortfolioState state;
  final String message;
  final Map<String, dynamic> metadata;

  const DecisionResult({
    required this.state,
    required this.message,
    this.metadata = const {},
  });
}
