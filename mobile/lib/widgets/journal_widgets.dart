import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../theme/app_theme.dart';

/// Draggable before / after comparison. Pass any two widgets (usually images
/// with BoxFit.cover). Drag the handle or tap anywhere to move the divider.
class BeforeAfterSlider extends StatefulWidget {
  const BeforeAfterSlider({
    super.key,
    required this.before,
    required this.after,
    this.height = 340,
    this.beforeLabel = 'BEFORE',
    this.afterLabel = 'AFTER',
  });

  final Widget before;
  final Widget after;
  final double height;
  final String beforeLabel;
  final String afterLabel;

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _pos = .5;

  Widget _label(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        letterSpacing: .8,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            final x = w * _pos;
            return MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) => setState(
                  () => _pos = ((x + d.delta.dx) / w).clamp(.03, .97),
                ),
                onTapDown: (d) => setState(
                  () => _pos = (d.localPosition.dx / w).clamp(.03, .97),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(child: widget.after),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: x,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          minWidth: w,
                          maxWidth: w,
                          minHeight: h,
                          maxHeight: h,
                          child: SizedBox(
                            width: w,
                            height: h,
                            child: widget.before,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: x - 1.5,
                      top: 0,
                      bottom: 0,
                      width: 3,
                      child: const ColoredBox(color: Colors.white),
                    ),
                    Positioned(
                      left: x - 21,
                      top: h / 2 - 21,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .25),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: _label(
                        widget.beforeLabel,
                        const Color(0xFF3F51B5),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: _label(widget.afterLabel, const Color(0xFF14A89B)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Mood {
  const _Mood(this.value, this.emoji, this.label, this.color);
  final int value;
  final String emoji;
  final String label;
  final Color color;
}

const List<_Mood> _moods = [
  _Mood(1, '\u{1F616}', 'Rough', Color(0xFFE5484D)),
  _Mood(2, '\u{1F615}', 'Meh', Color(0xFFF08A24)),
  _Mood(3, '\u{1F610}', 'Okay', Color(0xFFE8B008)),
  _Mood(4, '\u{1F642}', 'Good', Color(0xFF7BB661)),
  _Mood(5, '\u{1F929}', 'Great', Color(0xFF2E9E5B)),
];

String moodLabel(int? v) {
  for (final m in _moods) {
    if (m.value == v) return m.label;
  }
  return '';
}

Color moodColor(int? v) {
  for (final m in _moods) {
    if (m.value == v) return m.color;
  }
  return AppColors.muted;
}

String moodEmoji(int? v) {
  for (final m in _moods) {
    if (m.value == v) return m.emoji;
  }
  return '';
}

/// 1 to 5 mood buttons. Tap the selected one again to clear it.
class MoodPicker extends StatelessWidget {
  const MoodPicker({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final m in _moods)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Material(
                color: value == m.value
                    ? m.color.withValues(alpha: .16)
                    : AppColors.panel,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  mouseCursor: SystemMouseCursors.click,
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onChanged(value == m.value ? null : m.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: value == m.value ? m.color : AppColors.border,
                        width: value == m.value ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(m.emoji, style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 4),
                        Text(
                          m.label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: value == m.value ? m.color : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Tap-to-add quick tags for notes.
class QuickTags extends StatelessWidget {
  const QuickTags({
    super.key,
    required this.tags,
    required this.onTap,
    this.selected = const <String>{},
  });

  final List<String> tags;
  final ValueChanged<String> onTap;

  /// Lower-case tags that are already in the notes.
  final Set<String> selected;

  Widget _chip(String t) {
    final on = selected.contains(t.toLowerCase());
    return Material(
      color: on ? AppColors.primary : AppColors.lavender,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(20),
        onTap: () => onTap(t),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on ? Icons.check_rounded : Icons.add_rounded,
                size: 15,
                color: on ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                t,
                style: TextStyle(
                  color: on ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final t in tags) _chip(t)],
    );
  }
}
