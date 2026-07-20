import 'dart:convert';
import 'dart:io';

import '../models/strategy_report.dart';
import 'report_exporter.dart';

class IoReportExporter implements ReportExporter {
  @override
  Future<void> export(StrategyReport report) async {
    final dir = Directory('./reports');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final ts = report.timestamp.toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/strategy_report_$ts.json');

    final jsonStr = const JsonEncoder.withIndent('  ').convert(report.toJson());

    await file.writeAsString(jsonStr);
  }
}

ReportExporter createReportExporterImpl() => IoReportExporter();
