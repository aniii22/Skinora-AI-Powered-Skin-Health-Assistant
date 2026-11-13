import 'package:flutter/material.dart' hide Text;
import '../l10n/l10n.dart';

import '../auth/session.dart';
import '../theme/app_theme.dart';

bool _isPremium() => Session.I.user?.isPremium == true;

/// Small gold star. Hidden automatically once the user has Premium.
class PremiumStar extends StatelessWidget {
  const PremiumStar({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.I,
      builder: (context, _) {
        if (_isPremium()) return const SizedBox.shrink();
        return Tooltip(
          message: 'Premium feature',
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE6CE9A), AppColors.gold],
              ),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: .45),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.star_rounded, size: size * .68, color: AppColors.deep),
          ),
        );
      },
    );
  }
}

/// Puts the [PremiumStar] in the top-right corner of [child] when [show] is true.
class PremiumCorner extends StatelessWidget {
  const PremiumCorner({super.key, required this.show, required this.child});
  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        const Positioned(top: 6, right: 6, child: IgnorePointer(child: PremiumStar(size: 20))),
      ],
    );
  }
}