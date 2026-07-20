import '../models/strategy_report.dart';

abstract class ReportExporter {
  Future<void> export(StrategyReport report);
}
