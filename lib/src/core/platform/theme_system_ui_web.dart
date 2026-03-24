// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, unnecessary_null_comparison

import 'dart:html' as html;

import 'package:flutter/material.dart';

const String _lightSystemBarColor = '#FFFFFF';
const String _darkSystemBarColor = '#0F172A';

void applyThemeSystemUi(ThemeMode mode) {
  final isDark = mode == ThemeMode.dark;
  final barColor = isDark ? _darkSystemBarColor : _lightSystemBarColor;

  _setMeta('theme-color', barColor);
  _setMeta('msapplication-navbutton-color', barColor);
  _setMeta('msapplication-TileColor', barColor);
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
  _updateManifestThemeColor(isDark);
}

void _setMeta(String name, String content) {
  final selector = 'meta[name="$name"]';
  var meta = html.document.head?.querySelector(selector) as html.MetaElement?;
  if (meta is html.MetaElement) {
    meta.content = content;
  } else {
    final newMeta = html.MetaElement()..name = name;
    newMeta.content = content;
    html.document.head?.append(newMeta);
  }
}

void _updateManifestThemeColor(bool isDark) {
  try {
    final manifest =
        html.document.head?.querySelector('link[rel="manifest"]')
            as html.LinkElement?;
    if (manifest is html.LinkElement) {
      final href = manifest.href;
      if (href != null) {
        manifest.href = '$href?v=${isDark ? 'dark' : 'light'}';
      }
    }
  } catch (e) {
    // Silently fail if manifest manipulation doesn't work
  }
}
