import 'package:flutter/material.dart';

import 'theme_system_ui_stub.dart'
    if (dart.library.html) 'theme_system_ui_web.dart'
    as impl;

void applyThemeSystemUi(ThemeMode mode) {
  impl.applyThemeSystemUi(mode);
}
