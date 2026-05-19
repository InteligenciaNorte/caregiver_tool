import 'package:caregiver_tool/core/llm/model_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a well-formed manifest and lowercases the sha', () {
    const body = '''
{
  "model_version": "1.0.0",
  "model_filename": "gemma4-e2b_r32-q4_k_m.gguf",
  "size_bytes": 3427863872,
  "sha256": "81CE0AE4A3FB37040FAF37C6EEDC0985F0D7FA291E8D17A9820937CCDAB4158B",
  "sources": [
    {"kind": "split", "urls": ["a", "b"]},
    {"kind": "single", "url": "https://example.com/model.gguf"}
  ]
}
''';
    final m = ModelManifest.parse(body);
    expect(m.version, '1.0.0');
    expect(m.filename, 'gemma4-e2b_r32-q4_k_m.gguf');
    expect(m.sizeBytes, 3427863872);
    expect(m.url, 'https://example.com/model.gguf');
    expect(
      m.sha256,
      '81ce0ae4a3fb37040faf37c6eedc0985f0d7fa291e8d17a9820937ccdab4158b',
    );
  });

  test('throws when the single source / sha / filename is missing', () {
    expect(
      () => ModelManifest.parse('{"model_version":"1","sources":[]}'),
      throwsFormatException,
    );
  });
}
