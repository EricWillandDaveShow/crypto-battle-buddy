import 'report_exporter.dart';
import 'report_exporter_web.dart'
    if (dart.library.io) 'report_exporter_io.dart' as impl;

ReportExporter createReportExporter() {
  return impl.createReportExporterImpl();
}
