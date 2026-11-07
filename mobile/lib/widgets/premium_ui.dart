import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

class Brand {
  static const plum = Color(0xFF4A1D5C);
  static const plumDark = Color(0xFF2B1038);
  static const rose = Color(0xFFE8B4BC);
  static const gold = Color(0xFFC9A66B);
  static const bg = Color(0xFFFBF8F3);
  static const ink = Color(0xFF2B1038);
  static const muted = Color(0xFF6F6376);
}

/// White rounded card with soft shadow. Use instead of plain Card/Container.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Brand.plum.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Plum gradient banner for the top of a screen.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Brand.plumDark, Brand.plum],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Brand.plum.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Brand.plumDark,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Small gold "PREMIUM" pill. Put it next to locked features.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Brand.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Brand.gold),
      ),
      child: const Text(
        'PREMIUM',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Color(0xFF8A6A2F),
        ),
      ),
    );
  }
}
