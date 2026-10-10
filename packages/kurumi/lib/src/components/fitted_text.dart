import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fits wrapped text inside fixed bounds without changing their geometry.
class KurumiFittedText extends StatelessWidget {
  const KurumiFittedText(
    this.text, {
    this.textScaler,
    this.minimumWrappingFontSizeGain,
    this.alignment = AlignmentDirectional.centerStart,
    super.key,
  });

  final Text text;
  final TextScaler? textScaler;

  /// Required rendered font-size ratio before choosing more lines.
  /// Defaults to 1.5 in toolbar titles, and 1 elsewhere (including cards).
  final double? minimumWrappingFontSizeGain;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final defaults = DefaultTextStyle.of(context);
      final titleScope = KurumiToolbarTitleScope.maybeOf(context);
      final wrappingGain =
          minimumWrappingFontSizeGain ?? (titleScope == null ? 1.0 : 1.5);
      assert(wrappingGain >= 1);
      final style = defaults.style.merge(text.style);
      final scaler =
          textScaler ??
          text.textScaler ??
          titleScope?.textScaler ??
          MediaQuery.textScalerOf(context);
      final direction = text.textDirection ?? Directionality.of(context);
      final locale = text.locale ?? Localizations.maybeLocaleOf(context);
      final normalSize = style.fontSize ?? 20;
      final minimumSize = normalSize < 12 ? normalSize : 12.0;
      final painter = TextPainter(
        textDirection: direction,
        textScaler: scaler,
        locale: locale,
        textAlign: text.textAlign ?? defaults.textAlign ?? TextAlign.start,
        textHeightBehavior:
            text.textHeightBehavior ?? defaults.textHeightBehavior,
        strutStyle: text.strutStyle,
        textWidthBasis: text.textWidthBasis ?? defaults.textWidthBasis,
      );
      void measure(double size) {
        painter.text = TextSpan(
          text: text.data,
          children: text.textSpan == null ? null : [text.textSpan!],
          style: style.copyWith(fontSize: size),
        );
        painter.layout(maxWidth: constraints.maxWidth);
      }

      bool fits(double size, {int? lineLimit}) {
        measure(size);
        final lines = painter.computeLineMetrics();
        return painter.height <= constraints.maxHeight &&
            (lineLimit == null || lines.length <= lineLimit) &&
            lines.every((line) => line.width <= constraints.maxWidth);
      }

      double largestSize({int? lineLimit}) {
        if (fits(normalSize, lineLimit: lineLimit)) return normalSize;
        var lower = minimumSize;
        var upper = normalSize;
        for (var i = 0; i < 24; i++) {
          final middle = (lower + upper) / 2;
          if (fits(middle, lineLimit: lineLimit)) {
            lower = middle;
          } else {
            upper = middle;
          }
        }
        return lower;
      }

      var size = normalSize;
      int? maxLines;
      if (!fits(minimumSize)) {
        // No full layout fits: retain all physically visible lines at the floor.
        size = minimumSize;
        var height = 0.0;
        maxLines = 0;
        for (final line in painter.computeLineMetrics()) {
          height += line.height;
          if (height > constraints.maxHeight) break;
          maxLines = maxLines! + 1;
        }
        if (maxLines == 0) maxLines = 1;
      } else if (wrappingGain == 1) {
        size = largestSize();
      } else {
        final minimumLines = painter.computeLineMetrics();
        final firstLineCount = math.max(1, minimumLines.length);
        final minimumLineHeight = minimumLines.fold<double>(
          double.infinity,
          (height, line) => math.min(height, line.height),
        );
        measure(normalSize);
        var lastLineCount = math.max(
          firstLineCount,
          painter.computeLineMetrics().length,
        );
        if (constraints.maxHeight.isFinite && minimumLineHeight > 0) {
          lastLineCount = math.min(
            lastLineCount,
            (constraints.maxHeight / minimumLineHeight).floor(),
          );
        }
        size = largestSize(lineLimit: firstLineCount);
        var previousSize = size;
        for (var lines = firstLineCount + 1; lines <= lastLineCount; lines++) {
          final candidate = largestSize(lineLimit: lines);
          if (candidate > previousSize) {
            // Compare with the selected layout, not the preceding line count.
            // The tolerance only compensates for subpixel binary-search error.
            if (scaler.scale(candidate) + 0.00001 >=
                scaler.scale(size) * wrappingGain) {
              size = candidate;
            }
            previousSize = candidate;
          }
          if (candidate == normalSize) break;
        }
      }
      painter.dispose();
      final fittedStyle = style.copyWith(fontSize: size);
      final overflow = maxLines == null
          ? TextOverflow.visible
          : TextOverflow.ellipsis;
      final fitted = text.data != null
          ? Text(
              text.data!,
              key: text.key,
              style: fittedStyle,
              textScaler: scaler,
              locale: locale,
              textDirection: text.textDirection,
              textAlign: text.textAlign,
              strutStyle: text.strutStyle,
              textWidthBasis: text.textWidthBasis,
              textHeightBehavior: text.textHeightBehavior,
              semanticsLabel: text.semanticsLabel,
              semanticsIdentifier: text.semanticsIdentifier,
              selectionColor: text.selectionColor,
              softWrap: true,
              maxLines: maxLines,
              overflow: overflow,
            )
          : Text.rich(
              text.textSpan!,
              key: text.key,
              style: fittedStyle,
              textScaler: scaler,
              locale: locale,
              textDirection: text.textDirection,
              textAlign: text.textAlign,
              strutStyle: text.strutStyle,
              textWidthBasis: text.textWidthBasis,
              textHeightBehavior: text.textHeightBehavior,
              semanticsLabel: text.semanticsLabel,
              semanticsIdentifier: text.semanticsIdentifier,
              selectionColor: text.selectionColor,
              softWrap: true,
              maxLines: maxLines,
              overflow: overflow,
            );
      return Align(
        alignment: alignment,
        widthFactor: 1,
        heightFactor: 1,
        child: fitted,
      );
    },
  );
}

/// Carries the unclamped title scaler through nested Material app bars.
class KurumiToolbarTitleScope extends InheritedWidget {
  const KurumiToolbarTitleScope({
    required this.textScaler,
    required super.child,
    super.key,
  });
  final TextScaler textScaler;
  static KurumiToolbarTitleScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KurumiToolbarTitleScope>();
  @override
  bool updateShouldNotify(KurumiToolbarTitleScope oldWidget) =>
      textScaler != oldWidget.textScaler;
}
