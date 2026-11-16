// Usage (repo root): dart tools/check_i18n.dart
// Fails (exit 1) when UI strings would stay English in Hindi/Marathi.
import 'dart:io';

String unesc(String s) => s.replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{4})|\\(.)'),
      (m) => m[1] != null
          ? String.fromCharCode(int.parse(m[1]!, radix: 16))
          : (m[2] == 'n' ? ' ' : m[2]!),
    );

String norm(String s) => s
    .replaceAll('\u2019', "'")
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();

final keyRe = RegExp(
    r'''(?:^|\n)\s*(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")\s*:\s*\[''');
final textRe = RegExp(
    r'''\bText\(\s*(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")''');
final rawParamRe = RegExp(
    r'''\b(tooltip|hintText|labelText|helperText|errorText|semanticsLabel|semanticLabel)\s*:\s*(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")''');
final keyedParamRe = RegExp(
    r'''\b(title|message|label|confirmLabel|eyebrow|subtitle|actionLabel)\s*:\s*(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")''');
final numRe = RegExp(r'\d+(?:\.\d+)?');

void main() {
  final lib = Directory('mobile/lib');
  if (!lib.existsSync()) {
    stderr.writeln('Run from the repo root.');
    exit(2);
  }
  final keys = <String>{};
  for (final f in ['strings.dart', 'strings_extra.dart', 'strings_more.dart']) {
    final file = File('mobile/lib/l10n/$f');
    if (!file.existsSync()) continue;
    for (final m in keyRe.allMatches(file.readAsStringSync())) {
      keys.add(norm(unesc(m[1] ?? m[2]!)));
    }
  }
  final allow = <String>{};
  final al = File('tools/i18n_allowlist.txt');
  if (al.existsSync()) {
    for (final l in al.readAsLinesSync()) {
      if (l.trim().isNotEmpty && !l.startsWith('#')) allow.add(norm(l));
    }
  }

  bool known(String lit) {
    final n = norm(lit);
    if (n.length >= 20 && keys.any((k) => k.startsWith(n))) return true;
    if (keys.contains(n) || keys.contains(n.replaceAll(numRe, '{}'))) {
      return true;
    }
    for (final sep in [' \u00B7 ', ' \u2022 ', ': ', ', ', ' / ', ' - ']) {
      if (n.contains(sep) &&
          n.split(sep).any((p) =>
              keys.contains(p.trim()) ||
              keys.contains(p.trim().replaceAll(numRe, '{}')))) {
        return true;
      }
    }
    return false;
  }

  bool relevant(String s) =>
      RegExp(r'[A-Za-z]{3,}').hasMatch(s) &&
      !s.contains(r'$') &&
      !allow.contains(norm(s));

  final out = <String>[];
  final files = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) =>
          f.path.endsWith('.dart') &&
          !RegExp(r'backup|[\\/]l10n[\\/]').hasMatch(f.path));

  for (final f in files) {
    final src = f.readAsStringSync();
    final rel = f.path.replaceAll('\\', '/');
    int line(int o) => src.substring(0, o).split('\n').length;

    final hidesText = RegExp(r'hide\s+[^;]*\bText\b').hasMatch(src);
    if (src.contains('package:flutter/material.dart') &&
        !hidesText &&
        RegExp(r'\bText\(').hasMatch(src)) {
      out.add('$rel  MATERIAL_TEXT  imports material Text (never translated). '
          "Use: import 'package:flutter/material.dart' hide Text; + l10n import");
    }
    for (final m in textRe.allMatches(src)) {
      final s = unesc(m[1] ?? m[2]!);
      if (relevant(s) && !known(s)) {
        out.add('$rel:${line(m.start)}  MISSING_KEY  $s');
      }
    }
    for (final m in keyedParamRe.allMatches(src)) {
      final s = unesc(m[2] ?? m[3]!);
      if (relevant(s) && !known(s)) {
        out.add('$rel:${line(m.start)}  MISSING_KEY  ${m[1]}: $s');
      }
    }
    for (final m in rawParamRe.allMatches(src)) {
      final s = unesc(m[2] ?? m[3]!);
      if (relevant(s)) {
        out.add('$rel:${line(m.start)}  WRAP_WITH_Lang.I.tr  ${m[1]}: $s');
      }
    }
  }
  final seen = <String>{};
  final uniq = out.where(seen.add).toList();
  for (final l in uniq) {
    stdout.writeln(l);
  }
  stdout.writeln('\n${uniq.length} i18n problem(s).');
  exit(uniq.isEmpty ? 0 : 1);
}