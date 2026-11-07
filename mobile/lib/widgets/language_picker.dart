import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

const Map<String, String> _native = {
  'en': 'English',
  'hi': '\u0939\u093F\u0928\u094D\u0926\u0940',
  'mr': '\u092E\u0930\u093E\u0920\u0940',
};
const Map<String, String> _english = {
  'en': 'English',
  'hi': 'Hindi',
  'mr': 'Marathi',
};

String currentLanguageName() => _native[Lang.I.code] ?? 'English';

/// Bottom sheet to pick English / Hindi / Marathi.
Future<void> showLanguagePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => const _LanguageSheet(),
  );
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: Lang.I,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.lavender,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.translate_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Choose language',
                    style: AppText.cardTitle.copyWith(fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final code in Lang.codes) _row(context, code),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String code) {
    final selected = Lang.I.code == code;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: .10)
            : AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Lang.I.set(code);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _native[code] ?? code,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deep,
                        ),
                      ),
                      Text(_english[code] ?? code, style: AppText.caption),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? AppColors.primary : AppColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small "translate" button for the login screen or an AppBar.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Lang.I,
      builder: (context, _) => TextButton.icon(
        onPressed: () => showLanguagePicker(context),
        icon: const Icon(Icons.translate_rounded, size: 18),
        label: Text(currentLanguageName()),
      ),
    );
  }
}