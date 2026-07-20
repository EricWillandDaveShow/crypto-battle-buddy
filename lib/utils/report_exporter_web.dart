import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../models/strategy_report.dart';
import 'report_exporter.dart';

class WebReportExporter implements ReportExporter {
  @override
  Future<void> export(StrategyReport report) async {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(report.toJson());

    final blob = html.Blob([jsonStr], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final ts = report.timestamp.toIso8601String().replaceAll(':', '-');
    final filename = 'strategy_report_$ts.json';

    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();

    html.Url.revokeObjectUrl(url);
  }
}

ReportExporter createReportExporterImpl() => WebReportExporter();
