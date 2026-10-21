import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/token_store.dart';
import '../config/app_config.dart';
import '../error/api_exception.dart';
import '../error/error_parser.dart';
import 'json_codec.dart';

class RestClient {
  RestClient({
    required AppConfig config,
    required TokenStore tokenStore,
    http.Client? httpClient,
    this.onUnauthorized,
  }) : _config = config,
       _tokenStore = tokenStore,
       _http = httpClient ?? http.Client();

  final AppConfig _config;
  final TokenStore _tokenStore;
  final http.Client _http;

  /// Fired once per authenticated request that receives HTTP 401.
  /// Wired to [SessionExpired] — must not log tokens.
  void Function()? onUnauthorized;

  Future<Map<String, dynamic>?> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) {
    return send(
      method: 'GET',
      path: path,
      query: query,
      authenticated: authenticated,
    );
  }

  Future<Map<String, dynamic>?> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) {
    return send(
      method: 'POST',
      path: path,
      body: body,
      authenticated: authenticated,
    );
  }

  Future<Map<String, dynamic>?> patch(
    String path, {
    Object? body,
    bool authenticated = true,
  }) {
    return send(
      method: 'PATCH',
      path: path,
      body: body,
      authenticated: authenticated,
    );
  }

  Future<Map<String, dynamic>?> delete(
    String path, {
    Object? body,
    bool authenticated = true,
  }) {
    return send(
      method: 'DELETE',
      path: path,
      body: body,
      authenticated: authenticated,
    );
  }

  Future<Map<String, dynamic>?> send({
    required String method,
    required String path,
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (authenticated) {
      final token = _tokenStore.token;
      if (token == null || token.isEmpty) {
        throw const ApiException(
          code: 'UNAUTHENTICATED',
          message: 'Sign in first. Send Authorization: Bearer <token>.',
          statusCode: 401,
        );
      }
      headers['Authorization'] = 'Bearer $token';
    }

    final uri = _config.restUri(path, query);
    final encoded = body == null ? null : jsonEncode(body);
    final request = http.Request(method, uri)
      ..headers.addAll(headers)
      ..body = encoded ?? '';

    final http.Response response;
    try {
      final streamed = await _http.send(request);
      response = await http.Response.fromStream(streamed);
    } on http.ClientException catch (error) {
      throw ApiException(
        code: 'NETWORK',
        message: error.message,
        details: error.uri?.toString(),
      );
    }

    final decoded = decodeJsonMap(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final failure = parseRestFailure(
        statusCode: response.statusCode,
        body: decoded ?? (response.body.isEmpty ? null : response.body),
      );
      if (authenticated &&
          (response.statusCode == 401 || failure.isUnauthenticated)) {
        onUnauthorized?.call();
      }
      throw failure;
    }

    return decoded;
  }
}
