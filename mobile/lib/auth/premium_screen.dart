import '../screens/edit_account_screen.dart';
import 'premium_membership_screen.dart';
import '../widgets/profile_avatar.dart';

import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../services/api_client.dart' show ApiException;
import 'session.dart';
import '../theme/app_theme.dart';
import '../screens/skin_profile_screen.dart';
import '../screens/settings_screen.dart';

const _purple = Color(0xFF3F8F3A);
const _pink = Color(0xFFE59A7A);

/// Call from any catch block. Opens the upgrade dialog on a 402,
/// otherwise shows the error in a snackbar.
void showPremiumDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.workspace_premium, color: _pink, size: 36),
      title: const Text('Premium feature'),
      content: Text(message.replaceFirst('Premium: ', '')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Not now'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _purple),
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PremiumScreen()),
            );
          },
          child: const Text('See Premium'),
        ),
      ],
    ),
  );
}

/// For catch blocks: upgrade dialog on a 402, otherwise a snackbar.
void handleApiError(BuildContext context, Object e) {
  if (!context.mounted) return;
  if (e is ApiException && e.premiumRequired) {
    showPremiumDialog(context, e.message);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e is ApiException ? e.message : '$e')),
    );
  }
}

/// Account dropdown shown in the navbar.
class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});

  static void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  PopupMenuItem<String> _item(
    String value,
    IconData icon,
    Color color,
    String label, {
    String? hint,
  }) {
    final danger = value == 'logout';
    return PopupMenuItem<String>(
      value: value,
      height: 54,
      mouseCursor: SystemMouseCursors.click,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: danger ? AppColors.danger : AppColors.deep,
                  ),
                ),
                if (hint != null) Text(hint, style: AppText.caption),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: danger ? AppColors.danger : AppColors.muted,
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final user = Session.I.user;
    final email = user?.email ?? '';
    final rawName = (user?.name ?? '').trim();
    final name = rawName.isNotEmpty
        ? rawName
        : (email.contains('@') ? email.split('@').first : 'Skinora user');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deep, AppColors.primary, Color(0xFF7BB661)],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: .7),
                width: 2,
              ),
            ),
            child: ProfileAvatar(name: rawName, size: 50, onDark: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .88),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Full access',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: const Icon(
          Icons.logout_rounded,
          color: AppColors.danger,
          size: 32,
        ),
        title: const Text('Sign out?'),
        content: const Text('You will need to log in again to use Skinora.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) {
      // Pop pushed routes so AuthGate (home) is visible again.
      if (context.mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
      await Session.I.logout();
    }
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: Lang.I.tr('Account'),
    padding: EdgeInsets.zero,
    offset: const Offset(0, 50),
    elevation: 12,
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    clipBehavior: Clip.antiAlias,
    constraints: const BoxConstraints(minWidth: 270, maxWidth: 300),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ProfileAvatar(
          name: Session.I.user?.name ?? '',
          size: 34,
          onDark: false,
        ),
      ),
    ),
    onSelected: (v) async {
      if (v == 'premium') {
        _push(context, const PremiumScreen());
        return;
      }
      if (v == 'settings') {
        _push(context, const SettingsScreen());
        return;
      } // SETTINGS
      if (v == 'account') {
        await showEditAccountSheet(context);
        return;
      }
      if (v == 'language') {
        showLanguagePicker(context);
        return;
      }
      if (v == 'photo') {
        await showPhotoSheet(context);
      } else if (v == 'premium') {
        _push(context, const PremiumScreen());
      } else if (v == 'profile') {
        _push(context, const SkinProfileScreen());
      } else if (v == 'logout') {
        await _signOut(context);
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem<String>(
        value: 'account',
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            _header(),
            const Positioned(
              right: 14,
              top: 14,
              child: Icon(Icons.edit_rounded, size: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
      const PopupMenuItem<String>(enabled: false, height: 6, child: SizedBox()),
      _item(
        'profile',
        Icons.face_3_rounded,
        const Color(0xFF7C4DFF),
        'Skin profile',
        hint: 'Skin type and concerns',
      ),
      _item(
        'photo',
        Icons.photo_camera_rounded,
        const Color(0xFF14A89B),
        'Change photo',
        hint: 'Update your avatar',
      ),
      _item(
        'premium',
        Icons.workspace_premium,
        const Color(0xFFC9A66B),
        'Premium',
        hint: 'Plans and benefits',
      ),
      _item(
        'settings',
        Icons.settings_rounded,
        const Color(0xFF3F51B5),
        'Settings',
        hint: 'App preferences',
      ), // SETTINGS
      _item(
        'language',
        Icons.language_rounded,
        const Color(0xFF00897B),
        'Language',
        hint: 'English, हिन्दी, मराठी',
      ),
      const PopupMenuDivider(height: 10),
      _item('logout', Icons.logout_rounded, AppColors.danger, 'Sign out'),
      const PopupMenuItem<String>(enabled: false, height: 6, child: SizedBox()),
    ],
  );
}

/// The Premium page the whole app opens. It shows the demo membership page.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) => const PremiumMembershipScreen();
}
