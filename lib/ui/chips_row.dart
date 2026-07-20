import 'package:flutter/material.dart';

class HealthChipsRow extends StatelessWidget {
  final Color accentColor;

  const HealthChipsRow({super.key, this.accentColor = const Color(0xFF7DAAE8)});

  @override
  Widget build(BuildContext context) {
    final chips = const [
      ('🟢', 'Market OK', Color(0xFFEFF4FF)),
      ('🔥', 'Calm', Color(0xFFFFF3EA)),
      ('💰', '\$300 left', Color(0xFFEFF8F1)),
      ('🚨', '2 Alerts', Color(0xFFFFF6E8)),
      ('⏱️', 'Just now', Color(0xFFF3F1FF)),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: chips.map((chip) {
        final String message = switch (chip.$2) {
          'Market OK' => 'Market status: OK',
          'Calm' => 'Heat level: Calm',
          '\$300 left' => 'Budget remaining: \$300',
          '2 Alerts' => 'Active alerts: 2',
          'Just now' => 'Last updated: Just now',
          _ => chip.$2,
        };

        return Tooltip(
          message: message,
          child: Semantics(
            label: message,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {},
              child: AnimatedScale(
                duration: const Duration(milliseconds: 100),
                scale: 1,
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: chip.$3,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        chip.$1,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        chip.$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
