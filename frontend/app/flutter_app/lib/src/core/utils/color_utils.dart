import 'package:flutter/material.dart';

/// 将标签/封面色字符串解析为 [Color]。
///
/// 支持 [namedColors] 中列出的命名色，以及 `#RRGGBB` 形式的十六进制色。
/// 解析失败时回落到中性灰。
Color parseNamedColor(String s) {
  final named = namedColors[s];
  if (named != null) return named;
  if (s.length == 7 && s.codeUnitAt(0) == 0x23 /* '#' */) {
    final hex = int.tryParse(s.substring(1), radix: 16);
    if (hex != null) return Color(0xFF000000 | hex);
  }
  return const Color(0xFF6B7280);
}

/// 命名色到 ARGB 值的映射。
///
/// 与服务端标签/封面色取值集合对齐。
const Map<String, Color> namedColors = {
  'red': Color(0xFFEF4444),
  'orange': Color(0xFFF97316),
  'amber': Color(0xFFF59E0B),
  'yellow': Color(0xFFEAB308),
  'lime': Color(0xFF84CC16),
  'green': Color(0xFF22C55E),
  'emerald': Color(0xFF10B981),
  'teal': Color(0xFF14B8A6),
  'cyan': Color(0xFF06B6D4),
  'sky': Color( 0xFF0EA5E9),
  'blue': Color(0xFF3B82F6),
  'indigo': Color(0xFF6366F1),
  'violet': Color(0xFF8B5CF6),
  'purple': Color(0xFFA855F7),
  'fuchsia': Color(0xFFD946EF),
  'pink': Color(0xFFEC4899),
  'rose': Color(0xFFF43F5E),
  'gray': Color(0xFF6B7280),
  'slate': Color(0xFF64748B),
};
