import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Party-popper + confetti burst shown above a widget.
class Celebrate {
  Celebrate._();

  /// Screen rectangle of the widget that owns [key].
  static Rect? rectOfKey(GlobalKey? key) {
    final ctx = key?.currentContext;
    return ctx == null ? null : rectOf(ctx);
  }

  /// Short name used by the routine screens.
  static void show(BuildContext context, Rect rect,
      {double size = 60, String? message}) {
    showAtRect(context, rect, size: size);
    if (message != null && message.isNotEmpty) showToast(context, message);
  }

  /// Small "Congrats" popup at the top of the screen, hides by itself.
  static void showToast(BuildContext context, String task) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Toast(text: task, onDone: () => entry.remove()),
    );
    overlay.insert(entry);
  }

  /// Screen rectangle of the widget behind [context].
  static Rect? rectOf(BuildContext context) {
    final ro = context.findRenderObject();
    if (ro is RenderBox && ro.attached && ro.hasSize) {
      return ro.localToGlobal(Offset.zero) & ro.size;
    }
    return null;
  }

  static void showAtRect(BuildContext context, Rect rect, {double size = 60}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Burst(rect: rect, size: size, onDone: () => entry.remove()),
    );
    overlay.insert(entry);
  }
}

class _Burst extends StatefulWidget {
  const _Burst({required this.rect, required this.size, required this.onDone});
  final Rect rect;
  final double size;
  final VoidCallback onDone;
  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.rect.center;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = _c.value;
          final pop = Curves.elasticOut.transform((t / 0.45).clamp(0.0, 1.0));
          final fade = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0);
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _ConfettiPainter(center, t)),
              ),
              Positioned(
                left: center.dx - widget.size / 2,
                top: widget.rect.top - widget.size * 0.45,
                child: Opacity(
                  opacity: fade,
                  child: Transform.scale(
                    scale: pop,
                    child: Text(
                      '\u{1F389}',
                      style: TextStyle(
                        fontSize: widget.size * 0.8,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.origin, this.t);
  final Offset origin;
  final double t;

  static const _colors = [
    Color(0xFF4A1D5C),
    Color(0xFF7BB661),
    Color(0xFFC9A66B),
    Color(0xFF278BD8),
    Color(0xFFD9A7A0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const n = 22;
    final ease = Curves.easeOut.transform(t);
    for (var i = 0; i < n; i++) {
      final a = (i / n) * math.pi * 2 + (i.isEven ? 0.15 : -0.15);
      final dist = 40 + (i % 5) * 14.0;
      final dx = math.cos(a) * dist * ease;
      final dy = math.sin(a) * dist * ease + 60 * t * t;
      final p = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy - 10);
      canvas.rotate(a + t * 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, -2, 7, 4),
          const Radius.circular(1.5),
        ),
        p,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
class _Toast extends StatefulWidget {
  const _Toast({required this.text, required this.onDone});
  final String text;
  final VoidCallback onDone;
  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 70;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = _c.value;
          final pop = Curves.easeOutBack.transform((t / 0.15).clamp(0.0, 1.0));
          final fade = t < 0.8 ? 1.0 : (1 - (t - 0.8) / 0.2).clamp(0.0, 1.0);
          return Stack(
            children: [
              Positioned(
                top: top,
                left: 0,
                right: 0,
                child: Center(
                  child: Opacity(
                    opacity: fade,
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * pop,
                      child: Material(
                        color: Colors.transparent,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 340),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE8D9B5)),
                              boxShadow: const [
                                BoxShadow(color: Color(0x26000000), blurRadius: 14, offset: Offset(0, 4)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('\u{1F389}', style: TextStyle(fontSize: 22)),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'Congrats! You completed: ${widget.text}',
                                    style: const TextStyle(
                                      color: Color(0xFF2B1038),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}