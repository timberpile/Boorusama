/// PTS-based display schedule for an already decoded loop. Modulo time removes
/// the seek/reopen at the seam; the last frame gets only its original duration.
class GifLoopFrameClock {
  GifLoopFrameClock(List<int> timestamps, this.duration)
    : timestamps = List.unmodifiable(timestamps) {
    if (duration <= 0 || timestamps.isEmpty || timestamps.first != 0) {
      throw const FormatException('Invalid loop schedule');
    }
    for (var i = 0; i < timestamps.length; i++) {
      if (timestamps[i] >= duration ||
          (i > 0 && timestamps[i] <= timestamps[i - 1])) {
        throw const FormatException('Invalid frame timestamps');
      }
    }
  }

  final List<int> timestamps;
  final int duration;

  int frameAt(int elapsedMicroseconds) {
    final time = elapsedMicroseconds % duration;
    var low = 0;
    var high = timestamps.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (timestamps[middle] <= time) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low - 1;
  }
}
