import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// A single-response shelf mock server that records the last request it
/// received, for asserting on headers and query parameters.
class MockPixivServer {
  HttpServer? _server;
  Request? lastRequest;
  String responseBody = '{"illusts": [], "next_url": null}';
  int statusCode = 200;
  Map<String, String> responseHeaders = {'content-type': 'application/json'};

  Future<String> start() async {
    _server = await shelf_io.serve(_handle, 'localhost', 0);
    return 'http://localhost:${_server!.port}';
  }

  Future<void> stop() async {
    await _server?.close(force: true);
  }

  Response _handle(Request request) {
    lastRequest = request;
    return Response(statusCode, body: responseBody, headers: responseHeaders);
  }
}
