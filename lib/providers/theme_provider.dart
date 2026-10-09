import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;
  void set(ThemeMode m) => state = m;
}
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class BoolNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}
final hostModeProvider = NotifierProvider<BoolNotifier, bool>(BoolNotifier.new);
