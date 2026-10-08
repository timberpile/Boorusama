import 'dart:convert';

import 'package:dio/dio.dart';

import '../../common/feature.dart';
import '../post_v2_dto.dart';
import 'common.dart';

PostV2Dto? parseR34PostApi(
  Response response,
  Map<String, dynamic> context,
) {
  final dynamic data;
  if (response.data case final String value) {
    if (value.trimLeft().startsWith('<')) {
      throw const FormatException(
        'Rule34 returned HTML instead of JSON; site verification may be required',
      );
    }
    try {
      data = jsonDecode(value);
    } on FormatException {
      throw const FormatException('Rule34 returned invalid JSON');
    }
  } else {
    data = response.data;
  }
  // Only an empty API result means removed. Error/challenge responses must
  // remain retryable failures rather than changing the bookmark's status.
  if (data is! List) {
    if (data case {'error': final String message}) {
      throw FormatException('Rule34 API error: $message');
    }
    throw const FormatException('Expected a Rule34 post API list');
  }
  if (data.isEmpty) return null;
  if (data.length != 1 || data.single is! Map<String, dynamic>) {
    throw const FormatException('Expected a single Rule34 API post');
  }
  final post = PostV2Dto.fromJson(
    data.single as Map<String, dynamic>,
    context['baseUrl'] as String? ?? '',
  );
  if (post.id != context[P.postId]) {
    throw FormatException(
      'Rule34 API returned post ${post.id} instead of ${context[P.postId]}',
    );
  }
  if (post.fileUrl?.isEmpty ?? true) {
    throw const FormatException('Rule34 API post has no file URL');
  }
  return post;
}

PostV2Dto? parseR34PostHtml(
  Response response,
  Map<String, dynamic> context,
) => parseDefaultPostHtml(
  response,
  context,
  imageExtractor: DefaultHtmlImageExtractor(
    hashRegexPattern: r'/([a-f0-9]{40})\.[^/]*$',
    directoryRegexPattern: r'//images/(\d+)/',
    jsDirRegexPattern: r"'dir':\s*(\d+)",
    sampleHostTransform: (url) => switch (Uri.tryParse(url)) {
      Uri(host: final host) when !host.contains('wimg.') =>
        Uri.tryParse(url)?.replace(host: 'wimg.$host').toString() ?? url,
      _ => url,
    },
  ),
);
