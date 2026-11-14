import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

DateTime _lastOpen = DateTime.fromMillisecondsSinceEpoch(0);

/// Ignores a second tap that arrives while the first screen is still opening.
Future<void> openScreen(BuildContext context, Widget screen) async {
  final now = DateTime.now();
  if (now.difference(_lastOpen) < const Duration(milliseconds: 700)) return;
  _lastOpen = now;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.deep,
      ),
    );
}

/// Scrollable, top-aligned, max-width page body. Pull down to refresh.
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({super.key, required this.child, this.maxWidth = 1080});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: RefreshIndicator(
            onRefresh: () => AppScope.read(context).retryAll(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });
  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow, style: AppText.eyebrow),
        const SizedBox(height: 8),
        Semantics(header: true, child: Text(title, style: AppText.pageTitle)),
        const SizedBox(height: 8),
        Text(subtitle, style: AppText.bodyMuted),
        const SizedBox(height: 22),
      ],
    );
  }
}

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(kRadius);
    return Material(
      color: Colors.white,
      borderRadius: radius,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: .07),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class InfoNote extends StatelessWidget {
  const InfoNote(
    this.text, {
    super.key,
    this.icon = Icons.info_outline_rounded,
  });
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.deep,
                height: 1.45,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text.toUpperCase(), style: AppText.label),
  );
}

class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.primary,
    this.background = AppColors.border,
    this.height = 10,
  });
  final double value;
  final Color color;
  final Color background;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      minHeight: height,
      backgroundColor: background,
      color: color,
    ),
  );
}

/// One labelled row with a progress bar (used for daily history).
class HistoryBar extends StatelessWidget {
  const HistoryBar({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
    this.color = AppColors.primary,
    this.background = AppColors.border,
  });
  final String label;
  final String value;
  final double progress;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppText.caption),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                style: AppText.caption,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        AppProgressBar(
          value: progress,
          color: color,
          background: background,
          height: 8,
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => AppSurface(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.lavender,
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(height: 12),
        Text(title, style: AppText.cardTitle, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(message, style: AppText.bodyMuted, textAlign: TextAlign.center),
        if (actionLabel != null) ...[
          const SizedBox(height: 14),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppSurface(
    child: Column(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppColors.danger,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(message, style: AppText.body, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}

class ApiStatusCard extends StatelessWidget {
  const ApiStatusCard({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final connected = state.apiConnected;
    final checking = state.checkingApi;
    final color = checking
        ? AppColors.muted
        : connected == true
        ? AppColors.success
        : connected == false
        ? AppColors.danger
        : AppColors.muted;
    final title = checking
        ? 'Checking backend'
        : connected == true
        ? 'Backend connected'
        : connected == false
        ? 'Backend disconnected'
        : 'Backend not checked';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          if (checking)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              connected == true
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: color,
              size: 23,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.cardTitle.copyWith(fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  state.apiMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: Lang.I.tr('Retry connection'),
            onPressed: checking ? null : state.retryAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Single-field dialog. [onSubmit] returns an error message, or null on success (dialog closes).
Future<void> showTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  int maxLength = 60,
  required String confirmLabel,
  required Future<String?> Function(String value) onSubmit,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TextPromptDialog(
      title: title,
      label: label,
      initial: initial,
      maxLength: maxLength,
      confirmLabel: confirmLabel,
      onSubmit: onSubmit,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.maxLength,
    required this.confirmLabel,
    required this.onSubmit,
  });
  final String title;
  final String label;
  final String initial;
  final int maxLength;
  final String confirmLabel;
  final Future<String?> Function(String value) onSubmit;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial,
  );
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.onSubmit(_ctrl.text.trim());
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _ctrl,
              autofocus: true,
              maxLength: widget.maxLength,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: widget.label),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'This field is required'
                  : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Shows a spinner / error until the first data load has succeeded.
class LoadGate extends StatelessWidget {
  const LoadGate({super.key, required this.state, required this.builder});
  final AppState state;
  final Widget Function() builder;

  @override
  Widget build(BuildContext context) {
    if (state.loaded) return builder();
    if (state.loadError != null) {
      return ErrorRetry(message: state.loadError!, onRetry: state.retryAll);
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
