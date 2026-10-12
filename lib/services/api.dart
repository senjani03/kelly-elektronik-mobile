import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/config.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class Api {
  static String? token;

  static Future<dynamic> req(String method, String path,
      {Map? body, Map<String, String>? query}) async {
    final uri = Uri.parse(baseUrl + path).replace(queryParameters: query);
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    try {
      final data = body == null ? null : jsonEncode(body);
      final http.Response res = await switch (method) {
        'POST' => http.post(uri, headers: headers, body: data),
        'PUT' => http.put(uri, headers: headers, body: data),
        'DELETE' => http.delete(uri, headers: headers),
        _ => http.get(uri, headers: headers),
      }
          .timeout(const Duration(seconds: 15));
      final json = res.body.isEmpty ? {} : jsonDecode(res.body);
      if (res.statusCode >= 400) {
        String msg = json['message'] ?? 'Terjadi kesalahan';
        if (json['errors'] is Map && (json['errors'] as Map).isNotEmpty) {
          msg = (json['errors'] as Map).values.first[0].toString();
        }
        throw ApiException(msg);
      }
      return json;
    } on ApiException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('API request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw ApiException('Tidak dapat terhubung ke server');
    }
  }

  static Future<dynamic> uploadImage(
    String path, {
    required List<int> bytes,
    required String filename,
  }) =>
      uploadFile(
        path,
        bytes: bytes,
        filename: filename,
        field: 'proof',
        fallbackMessage: 'Gagal mengunggah bukti transfer',
        fallbackConnectionMessage: 'Tidak dapat mengunggah bukti transfer',
      );

  static Future<dynamic> uploadFile(
    String path, {
    required List<int> bytes,
    required String filename,
    String field = 'image',
    String method = 'POST',
    Map<String, String> fields = const {},
    String fallbackMessage = 'Gagal mengunggah file',
    String fallbackConnectionMessage = 'Tidak dapat mengunggah file',
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(baseUrl + path))
      ..headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      })
      ..fields.addAll({
        if (method.toUpperCase() != 'POST') '_method': method.toUpperCase(),
        ...fields,
      })
      ..files.add(http.MultipartFile.fromBytes(
        field,
        bytes,
        filename: filename,
      ));
    try {
      final streamed =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      final json = response.body.isEmpty ? {} : jsonDecode(response.body);
      if (response.statusCode >= 400) {
        String message = json['message'] ?? fallbackMessage;
        if (json['errors'] is Map && (json['errors'] as Map).isNotEmpty) {
          message = (json['errors'] as Map).values.first[0].toString();
        }
        throw ApiException(message);
      }
      return json;
    } on ApiException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('API file upload failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw ApiException(fallbackConnectionMessage);
    }
  }
}
