
## Rules
- Quota and date-boundary SQL: only via `monthStartSQL()` (backend/tz.go) and `reserveAIScan()`.
- All UI strings: via `Text('...')` from l10n.dart or `Lang.I.tr(...)`; add keys to l10n/strings*.dart.
- Run `git config core.hooksPath tools/hooks` once after cloning.
