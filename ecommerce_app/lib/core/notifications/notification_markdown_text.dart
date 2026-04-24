import 'package:flutter/material.dart';

final RegExp _boldPattern = RegExp(r'\*\*(.+?)\*\*');

/// Converts markdown-style bold segments (**text**) into Flutter [InlineSpan]s.
List<InlineSpan> notificationMarkdownSpans({
  required String input,
  required TextStyle? baseStyle,
  TextStyle? boldStyle,
}) {
  if (input.isEmpty) {
    return <InlineSpan>[TextSpan(text: '', style: baseStyle)];
  }
  final matches = _boldPattern.allMatches(input).toList();
  if (matches.isEmpty) {
    return <InlineSpan>[TextSpan(text: input, style: baseStyle)];
  }

  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final m in matches) {
    if (m.start > cursor) {
      spans.add(TextSpan(text: input.substring(cursor, m.start), style: baseStyle));
    }
    final boldText = m.group(1) ?? '';
    spans.add(TextSpan(text: boldText, style: boldStyle ?? baseStyle));
    cursor = m.end;
  }
  if (cursor < input.length) {
    spans.add(TextSpan(text: input.substring(cursor), style: baseStyle));
  }
  return spans;
}

/// Strips markdown bold markers while preserving text.
String stripNotificationMarkdownBold(String input) {
  if (input.isEmpty) return input;
  return input.replaceAllMapped(_boldPattern, (m) => m.group(1) ?? '');
}

