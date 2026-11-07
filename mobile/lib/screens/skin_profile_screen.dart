import 'package:flutter/material.dart' hide Text;

import '../l10n/l10n.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/profile_avatar.dart';

/// Read-only summary of the saved skin profile (used on Home and Profile).
class ProfileSummaryCard extends StatelessWidget {
  const ProfileSummaryCard({
    super.key,
    required this.profile,
    required this.onTap,
  });
  final SkinProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return AppSurface(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileSummaryAvatar(gender: p.gender),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.displayName.isEmpty ? 'Your skin profile' : p.displayName,
                  style: AppText.cardTitle.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                if (!p.isSet)
                  const Text(
                    'Add your skin type and concerns',
                    style: AppText.caption,
                  )
                else ...[
                  Text(
                    '${p.skinType == 'not_sure' ? 'Skin type not sure' : '${capitalize(p.skinType)} skin'}${p.sensitive ? ' \u00B7 reacts easily to products' : ''}',
                    style: AppText.caption,
                  ),
                  if (p.concerns.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in p.concerns)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.lavender,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              skinConcerns[c] ?? c,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

const _typeIcons = <String, IconData>{
  'normal': Icons.sentiment_satisfied_rounded,
  'oily': Icons.water_drop_rounded,
  'dry': Icons.air_rounded,
  'combination': Icons.contrast_rounded,
  'not_sure': Icons.help_outline_rounded,
};

const _typeHints = <String, String>{
  'normal': 'Balanced, comfortable',
  'oily': 'Shiny, esp. T-zone',
  'dry': 'Tight, rough or flaky',
  'combination': 'Oily T-zone, dry cheeks',
  'not_sure': 'No idea yet? That is fine',
};

const _concernIcons = <String, IconData>{
  'acne': Icons.bubble_chart_rounded,
  'dark_spots': Icons.circle,
  'dryness': Icons.grain_rounded,
  'oiliness': Icons.opacity_rounded,
  'redness': Icons.local_fire_department_rounded,
  'uneven_tone': Icons.gradient_rounded,
  'dullness': Icons.blur_on_rounded,
  'dehydrated': Icons.water_drop_outlined,
  'large_pores': Icons.grid_view_rounded,
  'dark_circles': Icons.visibility_off_rounded,
  'acne_scars': Icons.healing_rounded,
  'fine_lines': Icons.timeline_rounded,
};

class SkinProfileScreen extends StatefulWidget {
  const SkinProfileScreen({super.key});

  @override
  State<SkinProfileScreen> createState() => _SkinProfileScreenState();
}

class _SkinProfileScreenState extends State<SkinProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String _type;
  late String _gender;
  late final Set<String> _concerns;
  late bool _sensitive;
  late final bool _isEdit;
  bool _busy = false;
  bool _typeError = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = AppScope.read(context).profile;
    _isEdit = p.isSet;
    _name = TextEditingController(text: p.displayName);
    _type = p.skinType;
    _gender = p.gender;
    _concerns = {...p.concerns};
    _sensitive = p.sensitive;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final formOk = _formKey.currentState!.validate();
    setState(() => _typeError = _type.isEmpty);
    if (!formOk || _type.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await AppScope.read(context).saveProfile(
      SkinProfile(
        displayName: _name.text.trim(),
        skinType: _type,
        concerns: skinConcerns.keys.where(_concerns.contains).toList(),
        sensitive: _sensitive,
        gender: _gender,
      ),
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    showSnack(context, 'Skin profile saved');
    Navigator.of(context).pop();
  }

  // ---------- header ----------
  Widget _header() {
    final name = _name.text.trim();
    var done = 0;
    if (name.isNotEmpty) done++;
    if (_type.isNotEmpty) done++;
    if (_concerns.isNotEmpty) done++;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deep, AppColors.primary, Color(0xFF7BB661)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .4),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.face_3_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: const Text(
                        'Get to know your skin \u2728',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      name.isEmpty
                          ? 'Answer 3 quick steps to personalise your care.'
                          : 'Hi $name, let\u2019s personalise your care.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .9),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: done / 3,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: .22),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$done of 3 done',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .92),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- shared pieces ----------
  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kRadius),
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
  );

  Widget _sectionHead(
    String number,
    String title,
    String subtitle, {
    bool done = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.primary : AppColors.lavender,
          ),
          child: done
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
              : Text(
                  number,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.sectionTitle),
              const SizedBox(height: 2),
              Text(subtitle, style: AppText.caption),
            ],
          ),
        ),
      ],
    );
  }

  Widget _typeCard(String key, String label, double width) {
    final selected = _type == key;
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: selected ? AppColors.primary : AppColors.panel,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            mouseCursor: SystemMouseCursors.click,
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() {
              _type = key;
              _typeError = false;
            }),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: 1.4,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _typeIcons[key] ?? Icons.face_rounded,
                        color: selected ? Colors.white : AppColors.primary,
                      ),
                      const Spacer(),
                      if (selected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: selected ? Colors.white : AppColors.deep,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _typeHints[key] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: selected
                          ? Colors.white.withValues(alpha: .9)
                          : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _concernChip(String key, String label) {
    final selected = _concerns.contains(key);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.primary : AppColors.panel,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(22),
          onTap: () => setState(
            () => selected ? _concerns.remove(key) : _concerns.add(key),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected
                      ? Icons.check_rounded
                      : (_concernIcons[key] ?? Icons.circle_outlined),
                  size: 17,
                  color: selected ? Colors.white : AppColors.primary,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: selected ? Colors.white : AppColors.deep,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Save skin profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- screen ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit skin profile' : 'Skin profile'),
      ),
      bottomNavigationBar: _bottomBar(),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: 18),

                  // Name
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHead(
                          '1',
                          'About you',
                          'What should we call you?',
                          done: _name.text.trim().isNotEmpty,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _name,
                          maxLength: 40,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: Lang.I.tr('Display name (optional)'),
                            hintText: Lang.I.tr('e.g. Aniket'),
                            counterText: '',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gender
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gender (optional)',
                          style: AppText.cardTitle,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Used only to choose your avatar.',
                          style: AppText.caption,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final e in const {
                              'male': 'Male',
                              'female': 'Female',
                              '': 'Prefer not to say',
                            }.entries)
                              ChoiceChip(
                                label: Text(e.value),
                                selected: _gender == e.key,
                                checkmarkColor: Colors.white,
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _gender == e.key
                                      ? Colors.white
                                      : AppColors.deep,
                                ),
                                onSelected: (_) =>
                                    setState(() => _gender = e.key),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Skin type
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHead(
                          '2',
                          'Skin type',
                          'Pick the one that fits you best.',
                          done: _type.isNotEmpty,
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, c) {
                            final w = (c.maxWidth - 10) / 2;
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final e in skinTypes.entries)
                                  _typeCard(e.key, e.value, w),
                              ],
                            );
                          },
                        ),
                        if (_typeError)
                          const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text(
                              'Please choose your skin type.',
                              style: TextStyle(
                                color: AppColors.danger,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Concerns
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHead(
                          '3',
                          'Skin concerns',
                          'Select all that apply.',
                          done: _concerns.isNotEmpty,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final e in skinConcerns.entries)
                              _concernChip(e.key, e.value),
                          ],
                        ),
                        if (_concerns.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            '${_concerns.length} selected',
                            style: AppText.caption,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sensitive switch
                  _card(
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.lavender,
                          child: Icon(
                            Icons.spa_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Sensitive skin', style: AppText.cardTitle),
                              SizedBox(height: 2),
                              Text(
                                'Reacts easily to products? This works with any skin type.',
                                style: AppText.caption,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _sensitive,
                          activeThumbColor: AppColors.primary,
                          onChanged: (v) => setState(() => _sensitive = v),
                        ),
                      ],
                    ),
                  ),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const InfoNote(
                    'Skinora is a tracking and wellness app. It does not diagnose skin conditions or guarantee results.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
