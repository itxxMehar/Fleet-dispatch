import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/token_store.dart';
import '../config/app_config.dart';
import '../error/api_exception.dart';
import '../error/error_parser.dart';
import 'json_codec.dart';

class GraphQlClient {
  GraphQlClient({
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

  /// Fired when an authenticated GraphQL call is rejected as unauthenticated.
  void Function()? onUnauthorized;

  Future<Map<String, dynamic>> query({
    required String document,
    Map<String, dynamic>? variables,
    String? operationName,
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
          message: 'Sign in first.',
          statusCode: 401,
        );
      }
      headers['Authorization'] = 'Bearer $token';
    }

    final payload = <String, dynamic>{
      'query': document,
      'variables': ?variables,
      'operationName': ?operationName,
    };

    final http.Response response;
    try {
      response = await _http.post(
        _config.graphqlUri,
        headers: headers,
        body: jsonEncode(payload),
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        code: 'NETWORK',
        message: error.message,
        details: error.uri?.toString(),
      );
    }
    final decoded = decodeJsonMap(response.body) ?? <String, dynamic>{};

    if (decoded['errors'] is List) {
      try {
        throwIfGraphQlErrors(decoded);
      } on ApiException catch (error) {
        if (authenticated && error.isUnauthenticated) {
          onUnauthorized?.call();
        }
        rethrow;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final failure = parseRestFailure(
        statusCode: response.statusCode,
        body: decoded,
      );
      if (authenticated &&
          (response.statusCode == 401 || failure.isUnauthenticated)) {
        onUnauthorized?.call();
      }
      throw failure;
    }

    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const ApiException(
      code: 'GRAPHQL_ERROR',
      message: 'GraphQL response did not include data.',
    );
  }
}
