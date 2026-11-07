import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'settings_screen.dart';

class WaterScreen extends StatefulWidget {
  const WaterScreen({super.key});

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Runs one request at a time. Returns true on success.
  Future<bool> _run(Future<String?> Function() action) async {
    if (_busy) return false;
    setState(() => _busy = true);
    final err = await action();
    if (!mounted) return false;
    setState(() => _busy = false);
    if (err != null) {
      showSnack(context, err, error: true);
      return false;
    }
    return true;
  }

  Future<void> _addCustom() async {
    if (!_formKey.currentState!.validate()) return;
    final ml = int.parse(_ctrl.text.trim());
    if ((AppScope.read(context).water?.totalMl ?? 0) + ml > 5000) {
      showSnack(context, 'Daily limit reached (5000 ml)', error: true);
      return;
    }
    final ok = await _run(() => AppScope.read(context).addWater(ml));
    if (ok && mounted) {
      _formKey.currentState?.reset(); _ctrl.clear();
      FocusScope.of(context).unfocus();
      showSnack(context, 'Added $ml ml');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ResponsivePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            eyebrow: 'SMALL SIPS, STEADY HABITS',
            title: 'Hydration tracker',
            subtitle: 'Keep a simple count of the water you drink today.',
          ),
          LoadGate(state: s, builder: () => _content(context, s)),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, AppState s) {
    final w = s.water!;
    final over = w.totalMl - w.goalMl;
    final message = over > 0
        ? 'Goal reached, $over ml above your goal'
        : over == 0
        ? 'You reached your chosen goal!'
        : '${-over} ml left to your chosen goal';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.water.withValues(alpha: .14),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF8FD0F5), AppColors.water],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.water.withValues(alpha: .35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  size: 44,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${w.totalMl > 5000 ? 5000 : w.totalMl} ml',
                style: AppText.pageTitle.copyWith(fontSize: 30),
              ),
              const SizedBox(height: 4),
              Text(
                'of ${w.goalMl} ml \u00B7 ${glassesText(w.totalMl, w.glassMl)} of ${glassesText(w.goalMl, w.glassMl)} glasses',
                textAlign: TextAlign.center,
                style: AppText.caption,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.bodyMuted,
              ),
              const SizedBox(height: 18),
              AppProgressBar(
                value: w.progress,
                color: AppColors.water,
                background: AppColors.waterSoft,
                height: 12,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_busy || w.entries.isEmpty)
                          ? null
                          : () => _run(
                              () => AppScope.read(context).removeLastWater(),
                            ),
                      icon: const Icon(Icons.remove),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Remove last', maxLines: 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (_busy || w.totalMl >= 5000)
                          ? null
                          : () => _run(
                              () => AppScope.read(context).addWater(w.glassMl),
                            ),
                      icon: const Icon(Icons.add),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          w.totalMl >= 5000
                              ? 'Limit reached (5000 ml)'
                              : 'Add glass (${w.glassMl} ml)',
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppSurface(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Custom amount', style: AppText.cardTitle),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ctrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: Lang.I.tr('Amount (ml)'),
                        ),
                        onFieldSubmitted: (_) => _addCustom(),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'Enter an amount in ml';
                          final n = int.tryParse(t);
                          if (n == null || n < 1 || n > 1000)
                            return 'Enter 1 to 1000 ml';
                          final left = 5000 - (AppScope.read(context).water?.totalMl ?? 0);
                          if (n > left) {
                            return left <= 0
                                ? 'Daily limit reached (5000 ml)'
                                : 'Only $left ml left for today (limit 5000 ml)';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: (_busy || w.totalMl >= 5000) ? null : _addCustom,
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => openScreen(context, const SettingsScreen()),
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Change goal or glass size'),
          ),
        ),
        const SizedBox(height: 14),
        const SectionLabel("Today's entries"),
        AppSurface(
          child: w.entries.isEmpty
              ? const Text(
                  'Nothing logged yet today.',
                  style: AppText.bodyMuted,
                )
              : Column(
                  children: [
                    for (final e in w.entries.reversed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 18,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                TimeOfDay.fromDateTime(e.createdAt)
                                    .format(context),
                                style: AppText.body,
                              ),
                            ),
                            Text('${e.amountMl} ml', style: AppText.cardTitle),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 22),
        const SectionLabel('Last 7 days'),
        AppSurface(
          child: s.waterHistory.every((d) => d.totalMl == 0)
              ? const Text(
                  'Your daily history will appear here.',
                  style: AppText.bodyMuted,
                )
              : Column(
                  children: [
                    for (final d in s.waterHistory)
                      HistoryBar(
                        label: dayLabel(d.day),
                        value: '${d.totalMl > 5000 ? 5000 : d.totalMl} ml',
                        progress: w.goalMl == 0 ? 0 : d.totalMl / w.goalMl,
                        color: AppColors.water,
                        background: AppColors.waterSoft,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        const InfoNote(
          'Your goal is a personal target that you set. It is not medical advice, and needs vary from person to person.',
          icon: Icons.lightbulb_outline_rounded,
        ),
      ],
    );
  }
}
