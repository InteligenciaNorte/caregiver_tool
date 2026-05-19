/// The model manifest served from GitHub Pages (main:/docs/manifest.json),
/// so the model URL can change without an app update (hosting-guide).
/// Parsed by hand with `dart:convert` — no codegen (CLAUDE.md Hard Rule #1).
library;

import 'dart:convert';

class ModelManifest {
  const ModelManifest({
    required this.version,
    required this.filename,
    required this.sizeBytes,
    required this.sha256,
    required this.url,
  });

  final String version;
  final String filename;
  final int sizeBytes;

  /// Lowercase hex SHA-256 of the GGUF — verified after download so a
  /// truncated/corrupted/swapped 3.4 GB file never reaches the model
  /// loader.
  final String sha256;

  /// Direct, anonymous HTTPS GET (HF resolve URL pinned to a commit).
  final String url;

  factory ModelManifest.fromJson(Map<String, dynamic> json) {
    final sources = (json['sources'] as List?) ?? const [];
    final single = sources
        .cast<Map<String, dynamic>>()
        .firstWhere((s) => s['kind'] == 'single', orElse: () => const {});
    final url = single['url'] as String?;
    final sha = json['sha256'] as String?;
    final filename = json['model_filename'] as String?;
    if (url == null || sha == null || filename == null) {
      throw const FormatException('manifest missing url/sha256/filename');
    }
    return ModelManifest(
      version: (json['model_version'] as String?) ?? '0',
      filename: filename,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      sha256: sha.toLowerCase(),
      url: url,
    );
  }

  static ModelManifest parse(String body) =>
      ModelManifest.fromJson(jsonDecode(body) as Map<String, dynamic>);
}
