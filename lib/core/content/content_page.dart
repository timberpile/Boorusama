import 'package:equatable/equatable.dart';

/// A transient adapter-owned token. Request permission never comes from a cursor.
final class ContentCursor extends Equatable {
  ContentCursor(this.token) {
    if (token.isEmpty || token.length > 4096) {
      throw const FormatException('Invalid content cursor');
    }
  }
  final String token;
  @override
  List<Object?> get props => [token];
}

final class ContentPage<T> extends Equatable {
  ContentPage({
    required Iterable<T> items,
    this.next,
    this.total,
    this.sourceTotal,
  }) : items = List.unmodifiable(items) {
    if (total != null && total! < 0) {
      throw const FormatException('Invalid content total');
    }
  }
  final List<T> items;
  final ContentCursor? next;
  final int? total;

  /// Raw manifest extent, independent of the optional authorized count.
  final int? sourceTotal;
  @override
  List<Object?> get props => [items, next, total, sourceTotal];
}
