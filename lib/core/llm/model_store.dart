/// Download-on-first-launch for the GGUF (the model is too large to bundle;
/// hosting-guide). Reads the manifest from GitHub Pages, downloads the
/// model into the app's private support dir (resumable), verifies SHA-256,
/// and exposes progress. Networking is built-in `dart:io` only — no
/// http/dio package (CLAUDE.md Hard Rule #2); the one-time model fetch is
/// the agreed production exception to offline-first.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'model_manifest.dart';

/// GitHub Pages (main:/docs). Changing the model URL is a manifest edit,
/// not an app release.
const String kModelManifestUrl =
    'https://inteligencianorte.github.io/caregiver_tool/manifest.json';

/// Dev shortcut: `--dart-define=DEV_MODEL_PATH=/abs/path.gguf` skips the
/// download and uses a side-loaded file (fast local iteration). Empty in
/// production builds → real download.
const String _devModelPath = String.fromEnvironment('DEV_MODEL_PATH');

/// State of the one-time model acquisition. Sealed, no codegen.
sealed class ModelStatus {
  const ModelStatus();
}

class ModelChecking extends ModelStatus {
  const ModelChecking();
}

class ModelDownloading extends ModelStatus {
  const ModelDownloading(this.received, this.total);
  final int received;
  final int total;
  double get fraction => total > 0 ? received / total : 0;
}

class ModelVerifying extends ModelStatus {
  const ModelVerifying();
}

class ModelReady extends ModelStatus {
  const ModelReady(this.path);
  final String path;
}

class ModelError extends ModelStatus {
  const ModelError(this.message);
  final String message;
}

class ModelStore extends StateNotifier<ModelStatus> {
  ModelStore() : super(const ModelChecking());

  bool _running = false;

  /// Idempotent. Resolves the model: dev shortcut → already-present &
  /// verified → otherwise download + verify. Never throws; failures land
  /// in [ModelError] so the UI can offer retry (the partial file is kept
  /// for resume).
  Future<void> ensure() async {
    if (_running || state is ModelReady) return;
    _running = true;
    try {
      if (_devModelPath.isNotEmpty && File(_devModelPath).existsSync()) {
        state = const ModelReady(_devModelPath);
        return;
      }

      state = const ModelChecking();
      final manifest = await _fetchManifest();

      final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/models',
      );
      await dir.create(recursive: true);
      final finalFile = File('${dir.path}/${manifest.filename}');
      final marker = File('${finalFile.path}.sha256');
      final part = File('${finalFile.path}.part');

      // Fast path: already downloaded & verified (don't re-hash 3.4 GB
      // every launch — trust a marker written only after a passing check).
      if (finalFile.existsSync() &&
          marker.existsSync() &&
          (await marker.readAsString()).trim() == manifest.sha256 &&
          await finalFile.length() == manifest.sizeBytes) {
        state = ModelReady(finalFile.path);
        return;
      }

      await _download(manifest, part);

      state = const ModelVerifying();
      final digest = await sha256.bind(part.openRead()).first;
      if (digest.toString().toLowerCase() != manifest.sha256) {
        await part.delete().catchError((_) => part);
        state = const ModelError(
          "The downloaded model didn't verify. Tap to try again.",
        );
        return;
      }

      if (finalFile.existsSync()) await finalFile.delete();
      await part.rename(finalFile.path);
      await marker.writeAsString(manifest.sha256);
      state = ModelReady(finalFile.path);
    } catch (e) {
      state = ModelError(_friendly(e));
    } finally {
      _running = false;
    }
  }

  /// User tapped retry after a [ModelError]; resumes from the partial file.
  Future<void> retry() {
    if (state is ModelError) state = const ModelChecking();
    return ensure();
  }

  Future<ModelManifest> _fetchManifest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.getUrl(Uri.parse(kModelManifestUrl));
      final res = await req.close();
      if (res.statusCode != HttpStatus.ok) {
        throw HttpException('manifest HTTP ${res.statusCode}');
      }
      final body = await res.transform(utf8.decoder).join();
      return ModelManifest.parse(body);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _download(ModelManifest m, File part) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      var resumeFrom = part.existsSync() ? await part.length() : 0;
      if (resumeFrom > m.sizeBytes) {
        await part.delete();
        resumeFrom = 0;
      }
      final req = await client.getUrl(Uri.parse(m.url));
      req.followRedirects = true;
      req.maxRedirects = 8;
      if (resumeFrom > 0) {
        req.headers.add(HttpHeaders.rangeHeader, 'bytes=$resumeFrom-');
      }
      final res = await req.close();
      if (res.statusCode != HttpStatus.ok &&
          res.statusCode != HttpStatus.partialContent) {
        throw HttpException('model HTTP ${res.statusCode}');
      }
      // Server ignored the range → start over.
      if (resumeFrom > 0 && res.statusCode == HttpStatus.ok) resumeFrom = 0;

      final sink = part.openWrite(
        mode: resumeFrom > 0 ? FileMode.writeOnlyAppend : FileMode.writeOnly,
      );
      var received = resumeFrom;
      var lastEmit = 0;
      state = ModelDownloading(received, m.sizeBytes);
      try {
        await for (final chunk in res) {
          sink.add(chunk);
          received += chunk.length;
          // Throttle UI updates (chunks arrive thousands/sec).
          if (received - lastEmit >= 8 << 20 || received >= m.sizeBytes) {
            lastEmit = received;
            state = ModelDownloading(received, m.sizeBytes);
          }
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close(force: true);
    }
  }

  String _friendly(Object e) {
    if (e is SocketException || e is HttpException) {
      return 'Network problem while getting the model. Tap to try again.';
    }
    if (e is FormatException) {
      return "Couldn't read the model manifest. Tap to try again.";
    }
    return 'Something went wrong getting the model. Tap to try again.';
  }
}

final modelStoreProvider =
    StateNotifierProvider<ModelStore, ModelStatus>((ref) => ModelStore());
