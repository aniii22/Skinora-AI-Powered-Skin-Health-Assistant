import 'package:flutter/material.dart';

final WidgetStateProperty<MouseCursor> _click =
    WidgetStateProperty.resolveWith<MouseCursor>(
      (states) => states.contains(WidgetState.disabled)
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
    );

ButtonStyle _style(ButtonStyle? s) =>
    (s ?? const ButtonStyle()).copyWith(mouseCursor: _click);

ThemeData withPointerCursors(ThemeData t) => t.copyWith(
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: _style(t.elevatedButtonTheme.style),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: _style(t.filledButtonTheme.style),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: _style(t.outlinedButtonTheme.style),
  ),
  textButtonTheme: TextButtonThemeData(style: _style(t.textButtonTheme.style)),
  iconButtonTheme: IconButtonThemeData(style: _style(t.iconButtonTheme.style)),
  listTileTheme: t.listTileTheme.copyWith(mouseCursor: _click),
  switchTheme: t.switchTheme.copyWith(mouseCursor: _click),
  checkboxTheme: t.checkboxTheme.copyWith(mouseCursor: _click),
  radioTheme: t.radioTheme.copyWith(mouseCursor: _click),
);
