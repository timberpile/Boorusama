import 'dart:async';

import 'package:flutter/widgets.dart';

const imageCandidatePrimaryWindow = Duration(milliseconds: 800);
const imageCandidateFinalWindow = Duration(seconds: 5);

/// Each probe owns its cancellation; it must never cancel another consumer.
class ImageCandidate {
  const ImageCandidate({required this.image, required this.cancel});
  final ImageProvider image;
  final VoidCallback cancel;
}

/// Races decoded images, not HTTP responses. The first two candidates are the
/// primary formats. Other formats start only after their failure or deadline.
/// Use a request-identity key when URLs, credentials or cache domains change.
class ImageCandidatePicker extends StatefulWidget {
  const ImageCandidatePicker({
    required this.candidates,
    required this.placeholder,
    required this.builder,
    required this.onSelected,
    this.preferredIndex,
    super.key,
  });

  final List<ImageCandidate Function()> candidates;
  final Widget placeholder;
  final Widget Function(ImageProvider image) builder;
  final ValueChanged<int?> onSelected;
  final int? preferredIndex;

  @override
  State<ImageCandidatePicker> createState() => _ImageCandidatePickerState();
}

class _ImageCandidatePickerState extends State<ImageCandidatePicker> {
  final _requests = <int, _Probe>{};
  final _started = <int>{};
  final _pending = <int>{};
  late final _factories = widget.candidates;
  late final List<List<int>> _phases;
  late ImageConfiguration _configuration;
  Timer? _timer;
  var _phase = -1;
  var _scheduled = false;
  var _complete = false;
  ImageProvider? _winner;

  @override
  void initState() {
    super.initState();
    final preferred = widget.preferredIndex;
    _phases = [
      if (preferred != null && preferred >= 0 && preferred < _factories.length)
        [preferred],
      [for (var i = 0; i < _factories.length && i < 2; i++) i],
      [for (var i = 2; i < _factories.length; i++) i],
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    _configuration = createLocalImageConfiguration(context);
    // A cached provider may invoke its listener synchronously.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startNextPhase();
    });
  }

  void _startNextPhase() {
    if (!mounted || _complete) return;
    _timer?.cancel();
    List<int> indices;
    do {
      _phase++;
      if (_phase >= _phases.length) {
        if (_pending.isEmpty) {
          _finishWithoutImage();
        } else {
          _timer = Timer(imageCandidateFinalWindow, _finishWithoutImage);
        }
        return;
      }
      indices = _phases[_phase].where((i) => !_started.contains(i)).toList();
    } while (indices.isEmpty);
    _started.addAll(indices);
    _pending.addAll(indices);
    final finalPhase = _phase == _phases.length - 1;
    _timer = Timer(
      finalPhase ? imageCandidateFinalWindow : imageCandidatePrimaryWindow,
      finalPhase ? _finishWithoutImage : _startNextPhase,
    );
    for (final index in indices) {
      if (_complete || !mounted) break;
      ImageCandidate? candidate;
      try {
        final request = _factories[index]();
        candidate = request;
        final stream = request.image.resolve(_configuration);
        final listener = ImageStreamListener(
          (image, _) {
            image.dispose();
            if (!mounted || _complete) return;
            _complete = true;
            _timer?.cancel();
            _winner = request.image;
            for (final entry in _requests.entries.toList()) {
              if (entry.key != index) entry.value.close();
            }
            // Let the renderer attach before releasing the probe listener.
            // A keep-alive handle retains the completer without defeating the
            // renderer's TickerMode pause for animated WebP/AVIF images.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _requests[index]?.retainWithoutListening();
            });
            widget.onSelected(index);
            setState(() {});
          },
          onError: (error, stack) {
            if (!mounted || _complete) return;
            _requests[index]?.close();
            _pending.remove(index);
            if (_pending.isEmpty) _startNextPhase();
          },
        );
        _requests[index] = _Probe(request, stream, listener);
        stream.addListener(listener);
      } on Object {
        _requests[index]?.close();
        if (!_requests.containsKey(index)) candidate?.cancel();
        _pending.remove(index);
        if (_pending.isEmpty) _startNextPhase();
      }
    }
  }

  void _finishWithoutImage() {
    if (!mounted || _complete) return;
    _complete = true;
    _timer?.cancel();
    for (final request in _requests.values) {
      request.close();
    }
    widget.onSelected(null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final request in _requests.values) {
      request.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (_winner) {
    final image? => widget.builder(image),
    null => widget.placeholder,
  };
}

class _Probe {
  _Probe(this.candidate, this.stream, this.listener);
  final ImageCandidate candidate;
  final ImageStream stream;
  final ImageStreamListener listener;
  ImageStreamCompleterHandle? _keepAlive;
  var _listening = true;
  var _closed = false;

  void retainWithoutListening() {
    if (_closed || !_listening) return;
    _keepAlive = stream.completer?.keepAlive();
    _stopListening();
  }

  void _stopListening() {
    if (!_listening) return;
    _listening = false;
    stream.removeListener(listener);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    // Cancellation can complete a pending decoder after its last UI listener.
    stream.completer?.addEphemeralErrorListener((_, _) {});
    _stopListening();
    _keepAlive?.dispose();
    _keepAlive = null;
    candidate.cancel();
  }
}
