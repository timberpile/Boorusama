// Package imports:
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

class AutocompleteQuery extends Equatable {
  const AutocompleteQuery({
    required this.text,
    this.category,
    this.cancelToken,
  });

  const AutocompleteQuery.text(this.text) : category = null, cancelToken = null;

  final String text;
  final String? category;
  final CancelToken? cancelToken;

  @override
  List<Object?> get props => [text, category];
}
