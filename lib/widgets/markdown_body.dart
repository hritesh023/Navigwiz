import 'package:flutter/material.dart';

class MarkdownBody extends StatelessWidget {
  final String text;
  final ValueChanged<String> onOpenUrl;
  final double fontSize;

  const MarkdownBody({
    super.key,
    required this.text,
    required this.onOpenUrl,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = TextStyle(
        fontSize: fontSize, height: 1.5, color: theme.colorScheme.onSurface);

    if (text.contains('```')) {
      return _CodeBlockAwareMarkdown(
          text: text, baseStyle: baseStyle, onOpenUrl: onOpenUrl);
    }

    final blocks = <Widget>[];
    final lines = text.split('\n');
    var buffer = <TextSpan>[];

    void flush() {
      if (buffer.isEmpty) return;
      blocks.add(Text.rich(TextSpan(children: buffer, style: baseStyle)));
      buffer = [];
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        flush();
        continue;
      }

      if (RegExp(r'^#{1,3}\s').hasMatch(line)) {
        flush();
        final match = RegExp(r'^#{1,3}\s+').firstMatch(line);
        final level = match?.group(0)?.trim().length ?? 2;
        final headerText = line.substring(match?.group(0)?.length ?? 0);
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(headerText,
              style: TextStyle(
                  fontSize: level <= 2 ? fontSize + 2 : fontSize + 1,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface)),
        ));
        continue;
      }

      final bulletMatch = RegExp(r'^[\-\*]\s+(.*)$').firstMatch(line);
      if (bulletMatch != null) {
        flush();
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ',
                  style:
                      TextStyle(fontSize: fontSize, color: theme.colorScheme.primary)),
              Expanded(
                child: Text.rich(
                    TextSpan(
                        children: _inlineSpans(bulletMatch.group(1)!, baseStyle, theme),
                        style: baseStyle)),
              ),
            ],
          ),
        ));
        continue;
      }

      final numMatch = RegExp(r'^\d+[\.\)]\s+(.*)$').firstMatch(line);
      if (numMatch != null) {
        flush();
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${line.split(RegExp(r'[\.\)]'))[0]}.  ',
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary)),
              Expanded(
                child: Text.rich(
                    TextSpan(
                        children: _inlineSpans(numMatch.group(1)!, baseStyle, theme),
                        style: baseStyle)),
              ),
            ],
          ),
        ));
        continue;
      }

      buffer.addAll(_inlineSpans(line, baseStyle, theme));
      buffer.add(const TextSpan(text: '\n'));
    }
    flush();

    if (blocks.isEmpty) {
      return Text.rich(TextSpan(children: _inlineSpans(text, baseStyle, theme)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  List<TextSpan> _inlineSpans(
      String text, TextStyle baseStyle, ThemeData theme) {
    final spans = <TextSpan>[];
    final linkRegex = RegExp(r'\[([^\]]+)\]\(([^)\s]+)\)');
    final boldRegex = RegExp(r'\*\*([^*]+)\*\*');
    final codeRegex = RegExp(r'`([^`]+)`');

    final tokens = <({int start, int end, TextSpan span})>[];

    for (final m in linkRegex.allMatches(text)) {
      tokens.add((
        start: m.start,
        end: m.end,
        span: TextSpan(
          text: m.group(1),
          style: TextStyle(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
            fontSize: baseStyle.fontSize,
          ),
        ),
      ));
    }
    for (final m in boldRegex.allMatches(text)) {
      tokens.add((
        start: m.start,
        end: m.end,
        span: TextSpan(
            text: m.group(1),
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ));
    }
    for (final m in codeRegex.allMatches(text)) {
      tokens.add((
        start: m.start,
        end: m.end,
        span: TextSpan(
          text: m.group(1),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: (baseStyle.fontSize ?? 13) - 1,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
          ),
        ),
      ));
    }

    tokens.sort((a, b) => a.start.compareTo(b.start));

    var cursor = 0;
    for (final token in tokens) {
      if (token.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, token.start)));
      }
      spans.add(token.span);
      cursor = token.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    if (spans.isEmpty) spans.add(TextSpan(text: text));
    return spans;
  }
}

class _CodeBlockAwareMarkdown extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;
  final ValueChanged<String> onOpenUrl;

  const _CodeBlockAwareMarkdown({
    required this.text,
    required this.baseStyle,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = text.split('```');
    final children = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      if (i.isOdd) {
        var code = parts[i];
        if (code.contains('\n')) {
          code = code.substring(code.indexOf('\n') + 1);
        }
        children.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(10),
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            code.trimRight(),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ));
      } else if (parts[i].isNotEmpty) {
        children.add(
            MarkdownBody(text: parts[i], onOpenUrl: onOpenUrl, fontSize: baseStyle.fontSize ?? 13));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
