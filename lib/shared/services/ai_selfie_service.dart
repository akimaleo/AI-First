import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_selfie.dart';

/// Client for the `selfie-transform` Supabase edge function.
///
/// Responsibilities:
/// - Encode a local selfie file as a data URL
/// - Invoke the edge function with a prompt key and optional session/round ids
/// - Poll for completion in async mode
class AiSelfieService {
  AiSelfieService(this._client);

  final SupabaseClient _client;

  static const _functionName = 'selfie-transform';

  /// Kick off a transform and wait (server-side) for completion.
  /// Returns the finished job or the in-progress job if the server timed out.
  Future<AiSelfieJob> transform({
    required File selfie,
    required String promptKey,
    String? sessionId,
    String? roundId,
  }) async {
    final bytes = await selfie.readAsBytes();
    final mime = _sniffMime(bytes, selfie.path);
    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';

    final response = await _client.functions.invoke(
      _functionName,
      body: {
        'promptKey': promptKey,
        'image': dataUrl,
        if (sessionId != null) 'sessionId': sessionId,
        if (roundId != null) 'roundId': roundId,
        'mode': 'sync',
      },
    );

    final data = _parseBody(response);
    if (data['error'] != null) {
      throw AiSelfieException(
        data['error'] as String,
        jobId: data['jobId'] as String?,
      );
    }
    return AiSelfieJob.fromJson(data);
  }

  /// Kick off a transform without waiting. Use [pollJob] to check status.
  Future<AiSelfieJob> startAsync({
    required File selfie,
    required String promptKey,
    String? sessionId,
    String? roundId,
  }) async {
    final bytes = await selfie.readAsBytes();
    final mime = _sniffMime(bytes, selfie.path);
    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';

    final response = await _client.functions.invoke(
      _functionName,
      body: {
        'promptKey': promptKey,
        'image': dataUrl,
        if (sessionId != null) 'sessionId': sessionId,
        if (roundId != null) 'roundId': roundId,
        'mode': 'async',
      },
    );
    return AiSelfieJob.fromJson(_parseBody(response));
  }

  Future<AiSelfieJob> pollJob(String jobId) async {
    final response = await _client.functions.invoke(
      _functionName,
      method: HttpMethod.get,
      queryParameters: {'jobId': jobId},
    );
    return AiSelfieJob.fromJson(_parseBody(response));
  }

  /// Poll [jobId] until it reaches a terminal state or [timeout] elapses.
  Future<AiSelfieJob> waitForJob(
    String jobId, {
    Duration timeout = const Duration(seconds: 45),
    Duration initialDelay = const Duration(milliseconds: 800),
  }) async {
    final deadline = DateTime.now().add(timeout);
    var delay = initialDelay;
    while (DateTime.now().isBefore(deadline)) {
      final job = await pollJob(jobId);
      if (job.status.isTerminal) return job;
      await Future.delayed(delay);
      delay = Duration(
        milliseconds: (delay.inMilliseconds * 1.4).clamp(500, 3000).round(),
      );
    }
    return AiSelfieJob(jobId: jobId, status: AiSelfieStatus.processing);
  }

  Map<String, dynamic> _parseBody(FunctionResponse response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    throw AiSelfieException('Unexpected response: $data');
  }

  String _sniffMime(Uint8List bytes, String path) {
    if (bytes.length >= 4) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
      if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
      if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46) {
        return 'image/webp';
      }
    }
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

class AiSelfieException implements Exception {
  AiSelfieException(this.message, {this.jobId});

  final String message;
  final String? jobId;

  @override
  String toString() => 'AiSelfieException: $message';
}
