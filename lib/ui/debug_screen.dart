import 'package:flutter/material.dart';

import '../models/alert_event.dart';
import '../models/confirm_window.dart';
import '../models/lockdown.dart';
import '../models/strategy_profile.dart';

class DebugScreen extends StatelessWidget {
  final List<StrategyProfile> profiles;
  final StrategyProfile selectedProfile;
  final void Function(StrategyProfile) onProfileChanged;
  final bool lockdownEnabled;
  final String lockdownMessage;
  final ReleaseChecklist checklist;
  final void Function(ReleaseChecklist) onChecklistChanged;
  final void Function(bool enabled) onLockdownChanged;
  final ConfirmWindow confirmWindow;
  final VoidCallback onConfirm;
  final String heatForceMessage;
  final List<AlertEvent> alerts;
  final String pnlSummary;
  final String rebalanceSummary;
  final String budgetSummary;
  final String reportPretty;
  final String copyStatus;
  final VoidCallback onCopyReport;
  final VoidCallback onExportReport;
  final String feedName;
  final String snapshotPretty;
  final bool hasLastReport;

  const DebugScreen({
    super.key,
    required this.profiles,
    required this.selectedProfile,
    required this.onProfileChanged,
    required this.lockdownEnabled,
    required this.lockdownMessage,
    required this.checklist,
    required this.onChecklistChanged,
    required this.onLockdownChanged,
    required this.confirmWindow,
    required this.onConfirm,
    required this.heatForceMessage,
    required this.alerts,
    required this.pnlSummary,
    required this.rebalanceSummary,
    required this.budgetSummary,
    required this.reportPretty,
    required this.copyStatus,
    required this.onCopyReport,
    required this.onExportReport,
    required this.feedName,
    required this.snapshotPretty,
    required this.hasLastReport,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CBB Debug')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Profile:'),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: selectedProfile.name,
                    items: profiles
                        .map((p) => DropdownMenuItem(
                              value: p.name,
                              child: Text(p.name),
                            ))
                        .toList(),
                    onChanged: lockdownEnabled
                        ? null
                        : (name) {
                            if (name == null) return;
                            final prof = profiles.firstWhere(
                              (p) => p.name == name,
                              orElse: () => selectedProfile,
                            );
                            onProfileChanged(prof);
                          },
                  ),
                  const SizedBox(width: 12),
                  Text('Interval: ${selectedProfile.pollingInterval.inSeconds}s'),
                  const SizedBox(width: 12),
                  Text('Feed: $feedName'),
                ],
              ),
              ElevatedButton(
                onPressed: lockdownEnabled ? null : onConfirm,
                child: const Text('Confirm Execution (60s)'),
              ),
              Text('Confirm window: '
                  '${confirmWindow.isActive ? '${confirmWindow.secondsRemaining}s remaining' : 'inactive'}'),
              SwitchListTile(
                title: const Text('LOCKDOWN MODE'),
                subtitle: const Text('Freeze risky controls; requires checklist to disable.'),
                value: lockdownEnabled,
                onChanged: (v) => onLockdownChanged(v),
              ),
              CheckboxListTile(
                title: const Text('Reviewed Zones'),
                value: checklist.reviewedZones,
                onChanged: (v) =>
                    onChecklistChanged(checklist.copyWith(reviewedZones: v ?? false)),
              ),
              CheckboxListTile(
                title: const Text('Reviewed Budget'),
                value: checklist.reviewedBudget,
                onChanged: (v) =>
                    onChecklistChanged(checklist.copyWith(reviewedBudget: v ?? false)),
              ),
              CheckboxListTile(
                title: const Text('Reviewed Heat'),
                value: checklist.reviewedHeat,
                onChanged: (v) =>
                    onChecklistChanged(checklist.copyWith(reviewedHeat: v ?? false)),
              ),
              CheckboxListTile(
                title: const Text('Reviewed Execution Mode'),
                value: checklist.reviewedExecutionMode,
                onChanged: (v) =>
                    onChecklistChanged(checklist.copyWith(reviewedExecutionMode: v ?? false)),
              ),
              if (lockdownMessage.isNotEmpty)
                Text(lockdownMessage, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              if (heatForceMessage.isNotEmpty) ...[
                Text(heatForceMessage),
                const SizedBox(height: 4),
              ],
              Text('Alerts (${alerts.length}):'),
              if (alerts.isEmpty)
                const Text('No alerts')
              else
                ...alerts
                    .map((a) => Text('${a.type.name.toUpperCase()} - ${a.symbol}: ${a.message}')),
              const SizedBox(height: 12),
              Text(pnlSummary),
              const SizedBox(height: 4),
              Text(rebalanceSummary),
              const SizedBox(height: 4),
              Text(budgetSummary),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: reportPretty.isEmpty ? null : onCopyReport,
                    child: const Text('Copy Report JSON'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: reportPretty.isEmpty ? null : onExportReport,
                    child: const Text('Export Report'),
                  ),
                  const SizedBox(width: 8),
                  Text(copyStatus),
                ],
              ),
              if (hasLastReport) ...[
                const SizedBox(height: 6),
                const Text('Last Saved Report loaded'),
              ] else ...[
                const SizedBox(height: 6),
                const Text('No saved report found'),
              ],
              const SizedBox(height: 8),
              const Text('Strategy Report JSON:'),
              SelectableText(reportPretty),
              const SizedBox(height: 8),
              const Text('Raw Snapshot JSON:'),
              SelectableText(snapshotPretty),
            ],
          ),
        ),
      ),
    );
  }
}

extension on ReleaseChecklist {
  ReleaseChecklist copyWith({
    bool? reviewedZones,
    bool? reviewedBudget,
    bool? reviewedHeat,
    bool? reviewedExecutionMode,
  }) {
    return ReleaseChecklist(
      reviewedZones: reviewedZones ?? this.reviewedZones,
      reviewedBudget: reviewedBudget ?? this.reviewedBudget,
      reviewedHeat: reviewedHeat ?? this.reviewedHeat,
      reviewedExecutionMode: reviewedExecutionMode ?? this.reviewedExecutionMode,
    );
  }
}
