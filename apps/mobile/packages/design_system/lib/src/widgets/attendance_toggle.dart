import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Segmented control for a roll-call row, sized for a thumb in a halaqa.
///
/// Lives in the design system rather than the attendance feature so the hostel
/// roll call and the parent calendar render the same states with the same
/// colours — the point of a token layer.
///
/// Takes the caller's enum and its `values`, matched by `name`, so this widget
/// never imports a feature package: the dependency runs the other way.
///
/// Icon **and** colour, never colour alone — a warden checking a roster on a
/// dim corridor phone should not have to tell amber from red.
class AttendanceToggle<T extends Enum> extends StatelessWidget {
  const AttendanceToggle({
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final T value;

  /// The subset a teacher may pick. `LEAVE` is applied by the leave module and
  /// `HALF_DAY` is derived from a threshold, so neither belongs here.
  final List<T> options;

  final ValueChanged<T> onChanged;
  final bool enabled;

  /// name → (icon, colour, label). A value whose name is absent renders
  /// nothing, which surfaces the mismatch rather than guessing.
  static const Map<String, (IconData, Color, String)> _spec = {
    'present': (Icons.check, HufzTokens.present, 'Present'),
    'late': (Icons.schedule, HufzTokens.late, 'Late'),
    'absent': (Icons.close, HufzTokens.absent, 'Absent'),
    'excused': (Icons.event_busy, HufzTokens.excused, 'Excused'),
    'leave': (Icons.beach_access, HufzTokens.excused, 'On leave'),
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in options)
          if (_spec[option.name] case final spec?)
            _Segment(
              icon: spec.$1,
              colour: spec.$2,
              tooltip: spec.$3,
              isSelected: option == value,
              enabled: enabled,
              onTap: () => onChanged(option),
            ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.colour,
    required this.tooltip,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final Color colour;
  final String tooltip;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: tooltip,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(HufzTokens.radius.sm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 44,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isSelected ? colour : Colors.transparent,
              borderRadius: BorderRadius.circular(HufzTokens.radius.sm),
              border: Border.all(
                color: isSelected ? colour : scheme.outline.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isSelected
                  ? Colors.white
                  : enabled
                  ? scheme.onSurfaceVariant
                  : Theme.of(context).disabledColor,
            ),
          ),
        ),
      ),
    );
  }
}
