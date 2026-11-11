// Package imports:
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({
    required this.isPlaying,
    required this.onPlayingChanged,
    super.key,
    this.padding,
    this.semanticLabel,
  });

  final ValueListenable<bool> isPlaying;
  final void Function(bool value) onPlayingChanged;
  final EdgeInsetsGeometry? padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: isPlaying,
      builder: (_, playing, _) => Semantics(
        button: true,
        enabled: true,
        label: semanticLabel,
        onTap: () => onPlayingChanged(playing),
        child: KurumiCircularIconButton(
          constraints: const BoxConstraints(),
          padding: padding ?? EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          semanticLabel: semanticLabel,
          onPressed: () => onPlayingChanged(playing),
          icon: Icon(
            playing ? Symbols.pause : Symbols.play_arrow,
            fill: 1,
          ),
        ),
      ),
    );
  }
}
