import 'dart:math' as math;
import 'dart:typed_data';

/// All times are source-relative presentation timestamps in microseconds.
/// End boundaries are exclusive. Detection never changes source cadence.
class GifLoopRequest {
  const GifLoopRequest({
    required this.start,
    required this.end,
    required this.sourceDuration,
    this.minimumDuration = 200000,
  });

  final int start;
  final int end;
  final int sourceDuration;
  final int minimumDuration;

  int get radius => math.min(350000, (end - start) ~/ 4);
  bool get isValid => start >= 0 && end <= sourceDuration &&
      end - start >= minimumDuration && minimumDuration > 0 && radius > 0;
  // Only rounding noise is ignored; a real source-frame edit stays visible.
  bool get isFullSource => start <= 1 && sourceDuration - end <= 1;
  int get decodeStart => math.max(0, start - radius - 100000);
  int get decodeEnd => math.min(sourceDuration, end + radius + 450000);
}

class GifLoopFrames {
  const GifLoopFrames({
    required this.pixels,
    required this.timestamps,
    this.pixelsPerFrame = 64 * 64,
  });

  final Uint8List pixels;
  final List<int> timestamps;
  final int pixelsPerFrame;
}

enum GifLoopMatchKind { none, repeatedSequence, seamOnly }
enum GifLoopNoMatchReason { noMatch, invalidFrames, budget, cancelled, unavailable }

class GifLoopResult {
  const GifLoopResult.noMatch([
    this.reason = GifLoopNoMatchReason.noMatch,
  ]) : kind = GifLoopMatchKind.none, start = null, end = null;

  const GifLoopResult.match(this.kind, this.start, this.end) : reason = null;

  final GifLoopMatchKind kind;
  final int? start;
  final int? end;
  final GifLoopNoMatchReason? reason;
  bool get matched => kind != GifLoopMatchKind.none;
}

/// Pure CPU work: run in a cancellable isolate, never on the UI isolate.
/// Thresholds deliberately match the guided prototype; they are not calibrated
/// probabilities. No candidate thinning: exhausted budgets mean no suggestion.
GifLoopResult refineGifLoop(
  GifLoopFrames frames,
  GifLoopRequest request, {
  int maximumComparisons = 65000,
}) {
  final pts = frames.timestamps;
  if (!request.isValid || pts.length < 3 || pts.length > 4500 ||
      frames.pixelsPerFrame <= 0 || frames.pixelsPerFrame > 4096 ||
      frames.pixels.length != pts.length * frames.pixelsPerFrame ||
      pts.first < 0 || pts.last >= request.sourceDuration) {
    return const GifLoopResult.noMatch(GifLoopNoMatchReason.invalidFrames);
  }
  final intervals = <int>[];
  for (var i = 1; i < pts.length; i++) {
    if (pts[i] <= pts[i - 1]) {
      return const GifLoopResult.noMatch(GifLoopNoMatchReason.invalidFrames);
    }
    intervals.add(pts[i] - pts[i - 1]);
  }
  intervals.sort();
  final interval = _percentile(intervals.map((v) => v.toDouble()).toList(), .5);
  final tolerance = (interval * .75).round().clamp(18000, 80000).toInt();
  final starts = <int>[];
  final ends = <(int, int)>[];
  for (var i = 0; i < pts.length; i++) {
    if ((pts[i] - request.start).abs() <= request.radius) starts.add(i);
    if ((pts[i] - request.end).abs() <= request.radius) ends.add((i, pts[i]));
  }
  // Only the real source duration is an extra exclusive end. The last PTS of
  // an analysis slice must never masquerade as the end of the whole source.
  if ((request.sourceDuration - request.end).abs() <= request.radius) {
    ends.add((pts.length, request.sourceDuration));
  }
  if (starts.isEmpty || ends.isEmpty) return const GifLoopResult.noMatch();

  final errors = _FrameErrors(frames, maximumComparisons);
  try {
    final adjacentMotion = [
      for (var i = 1; i < pts.length; i++) errors.between(i - 1, i),
    ];
    _Candidate? best;
    for (final first in starts) {
      // A cached exact diversity gate avoids sorting every candidate's entire
      // selected region. Its result is equivalent to linear p85 >= .018.
      final diverse = _diversityByEnd(first, ends.last.$1, errors);
      for (final (endIndex, end) in ends) {
        final start = pts[first];
        final duration = end - start;
        if (duration < request.minimumDuration || endIndex <= first + 1 ||
            !diverse[endIndex - first]) continue;
        final span = math.min(400000, (duration * .45).round());
        final sequence = <double>[];
        var seenTime = 0;
        for (var i = first; i < endIndex && pts[i] - start <= span; i++) {
          final match = _closest(pts, pts[i] + duration, tolerance);
          if (match == null || match <= i) continue;
          sequence.add(errors.between(i, match));
          seenTime = math.max(seenTime, pts[i] - start);
        }
        final hasEvidence = sequence.length >= 3 &&
            seenTime >= math.min(160000, (span * .70).round());
        final mean = hasEvidence
            ? sequence.reduce((a, b) => a + b) / sequence.length : 1.0;
        sequence.sort();
        final repeated = hasEvidence && mean <= .041 &&
            _percentile(sequence, .95) <= .077;
        // Absence in a partial decode is not absence in the source. Do not
        // turn missing/contradictory available evidence into a seam hint.
        if (!repeated && (hasEvidence ||
            request.sourceDuration - end >= math.max(250000, 3 * interval))) {
          continue;
        }
        final seam = errors.between(first, endIndex - 1);
        if (!repeated) {
          // Context outside the candidate must not relax its seam threshold.
          final motion = adjacentMotion.sublist(first, endIndex - 1)..sort();
          final seamLimit = math.min(.075, math.max(.010, _percentile(motion, .8) * 1.8));
          if (seam > seamLimit) continue;
        }
        final displacement = ((start - request.start).abs() +
            (end - request.end).abs()) / request.radius;
        final candidate = _Candidate(
          repeated ? GifLoopMatchKind.repeatedSequence : GifLoopMatchKind.seamOnly,
          start, end,
          repeated ? mean + .0015 * displacement + .10 * seam
              : seam + .004 * displacement,
          displacement,
        );
        if (best == null || candidate.isBetterThan(best)) best = candidate;
      }
    }
    return best == null ? const GifLoopResult.noMatch()
        : GifLoopResult.match(best.kind, best.start, best.end);
  } on _ComparisonBudgetExceeded {
    return const GifLoopResult.noMatch(GifLoopNoMatchReason.budget);
  }
}

class _Candidate {
  const _Candidate(this.kind, this.start, this.end, this.score, this.displacement);
  final GifLoopMatchKind kind;
  final int start;
  final int end;
  final double score;
  final double displacement;

  bool isBetterThan(_Candidate other) {
    if (kind != other.kind) return kind == GifLoopMatchKind.repeatedSequence;
    if ((score - other.score).abs() > 1e-12) return score < other.score;
    return displacement < other.displacement;
  }
}

class _ComparisonBudgetExceeded implements Exception {}

class _FrameErrors {
  _FrameErrors(this.frames, this.limit);
  final GifLoopFrames frames;
  final int limit;
  final Map<int, double> cache = {};

  double between(int a, int b) {
    if (a == b) return 0;
    final low = math.min(a, b);
    final high = math.max(a, b);
    final key = low * frames.timestamps.length + high;
    if (cache[key] case final value?) return value;
    if (cache.length >= limit) throw _ComparisonBudgetExceeded();
    final size = frames.pixelsPerFrame;
    final first = low * size;
    final second = high * size;
    var sum = 0;
    for (var p = 0; p < size; p++) {
      sum += (frames.pixels[first + p] - frames.pixels[second + p]).abs();
    }
    return cache[key] = sum / (255 * size);
  }
}

List<bool> _diversityByEnd(int first, int end, _FrameErrors errors) {
  final result = List<bool>.filled(math.max(0, end - first) + 1, false);
  var below = 0;
  var maxBelow = 0.0;
  var minAbove = 1.0;
  for (var i = first; i < end; i++) {
    final error = errors.between(first, i);
    if (error < .018) {
      below++;
      maxBelow = math.max(maxBelow, error);
    } else {
      minAbove = math.min(minAbove, error);
    }
    final count = i - first + 1;
    final rank = (count - 1) * .85;
    if (below <= rank.floor()) {
      result[count] = true;
    } else if (below <= rank.ceil()) {
      result[count] = maxBelow + (minAbove - maxBelow) * (rank - rank.floor()) >= .018;
    }
  }
  return result;
}

int? _closest(List<int> pts, int wanted, int tolerance) {
  var low = 0;
  var high = pts.length;
  while (low < high) {
    final middle = (low + high) ~/ 2;
    if (pts[middle] < wanted) { low = middle + 1; } else { high = middle; }
  }
  int? best;
  for (final i in [low - 1, low]) {
    if (i < 0 || i >= pts.length) continue;
    if (best == null || (pts[i] - wanted).abs() < (pts[best] - wanted).abs()) best = i;
  }
  return best != null && (pts[best] - wanted).abs() <= tolerance ? best : null;
}

double _percentile(List<double> sorted, double fraction) {
  if (sorted.isEmpty) return 1;
  final index = (sorted.length - 1) * fraction;
  final lo = index.floor();
  final hi = index.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (index - lo);
}
