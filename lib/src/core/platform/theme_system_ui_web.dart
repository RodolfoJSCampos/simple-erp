// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:flutter/material.dart';

const String _lightSystemBarColor = '#FFFFFF';
const String _darkSystemBarColor = '#0F172A';

void applyThemeSystemUi(ThemeMode mode) {
  final isDark = mode == ThemeMode.dark;
  final barColor = isDark ? _darkSystemBarColor : _lightSystemBarColor;

  _setMeta('theme-color', barColor);
  _setMeta('msapplication-navbutton-color', barColor);
  _setMeta('color-scheme', isDark ? 'dark' : 'light');
  _setMeta(
    'apple-mobile-web-app-status-bar-style',
    isDark ? 'black-translucent' : 'default',
  );

  html.document.documentElement?.style.setProperty(
    'background-color',
    barColor,
  );
  html.document.body?.style.setProperty('background-color', barColor);
}

void _setMeta(String name, String content) {
  final selector = 'meta[name="$name"]';
  var meta = html.document.head?.querySelector(selector) as html.MetaElement?;
  meta ??= html.MetaElement()..name = name;
  meta.content = content;
  if (meta.parent == null) {
    html.document.head?.append(meta);
  }
}
