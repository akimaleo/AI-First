enum AiSelfieStatus {
  pending,
  processing,
  succeeded,
  failed,
  cancelled;

  static AiSelfieStatus fromString(String value) {
    return AiSelfieStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => AiSelfieStatus.pending,
    );
  }

  bool get isTerminal =>
      this == succeeded || this == failed || this == cancelled;
}

class AiSelfiePrompt {
  const AiSelfiePrompt({required this.key, required this.label});

  final String key;
  final String label;

  factory AiSelfiePrompt.fromJson(Map<String, dynamic> json) {
    return AiSelfiePrompt(
      key: json['key'] as String,
      label: json['label'] as String,
    );
  }
}

class AiSelfieJob {
  const AiSelfieJob({
    required this.jobId,
    required this.status,
    this.outputUrl,
    this.latencyMs,
    this.error,
  });

  final String jobId;
  final AiSelfieStatus status;
  final String? outputUrl;
  final int? latencyMs;
  final String? error;

  factory AiSelfieJob.fromJson(Map<String, dynamic> json) {
    return AiSelfieJob(
      jobId: json['jobId'] as String,
      status: AiSelfieStatus.fromString(json['status'] as String),
      outputUrl: json['outputUrl'] as String?,
      latencyMs: json['latencyMs'] as int?,
      error: json['error'] as String?,
    );
  }
}

/// Built-in prompt scenario keys that match the edge function's PROMPT_TEMPLATES.
/// Kept in sync manually to avoid a network round-trip at game-start time.
class AiSelfiePromptKeys {
  AiSelfiePromptKeys._();

  static const thirdEye = 'third_eye';
  static const zombie = 'zombie';
  static const robot = 'robot';
  static const alienSkin = 'alien_skin';
  static const vampire = 'vampire';
  static const cartoon = 'cartoon';
  static const werewolf = 'werewolf';
  static const cyberpunk = 'cyberpunk';
  static const angel = 'angel';
  static const devil = 'devil';

  static const List<AiSelfiePrompt> all = [
    AiSelfiePrompt(key: thirdEye, label: 'Third Eye'),
    AiSelfiePrompt(key: zombie, label: 'Zombie'),
    AiSelfiePrompt(key: robot, label: 'Robot'),
    AiSelfiePrompt(key: alienSkin, label: 'Alien'),
    AiSelfiePrompt(key: vampire, label: 'Vampire'),
    AiSelfiePrompt(key: cartoon, label: 'Cartoon'),
    AiSelfiePrompt(key: werewolf, label: 'Werewolf'),
    AiSelfiePrompt(key: cyberpunk, label: 'Cyberpunk'),
    AiSelfiePrompt(key: angel, label: 'Angel'),
    AiSelfiePrompt(key: devil, label: 'Devil'),
  ];
}
