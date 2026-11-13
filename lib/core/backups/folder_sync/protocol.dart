import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as signing;
import 'package:uuid/uuid.dart';

import 'limits.dart';

export 'limits.dart';

const syncSourceKinds = {'bookmarks', 'following_topics'};

String canonicalSyncJson(Object? value) => jsonEncode(_canonical(value, 0));

Object? _canonical(Object? value, int depth) {
  if (depth > 64) throw const FormatException('Sync metadata nesting limit');
  if (value is Map) {
    if (value.keys.any((key) => key is! String)) {
      throw const FormatException('Invalid sync object key');
    }
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key], depth + 1)};
  }
  if (value is Iterable) {
    return value.map((item) => _canonical(item, depth + 1)).toList();
  }
  return value;
}

Uint8List syncJsonBytes(Object? value) =>
    Uint8List.fromList(utf8.encode(canonicalSyncJson(value)));
String syncDigest(List<int> bytes) => sha256.convert(bytes).toString();

Map<String, dynamic> decodeSyncObject(
  List<int> bytes, {
  int maximum = folderSyncMaxMetadataBytes,
}) {
  if (maximum < 0) throw ArgumentError.value(maximum, 'maximum');
  if (bytes.length > maximum) {
    throw const FormatException('Sync metadata exceeds byte limit');
  }
  final value = jsonDecode(utf8.decode(bytes));
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid sync metadata');
  }
  return value;
}

String syncUuid(Object? value) {
  if (value is! String ||
      !Uuid.isValidUUID(fromString: value) ||
      value != value.toLowerCase()) {
    throw const FormatException('Invalid sync identity');
  }
  return value;
}

String syncString(Object? value) {
  if (value is! String) throw const FormatException('Invalid sync string');
  return value;
}

int syncPositiveInteger(Object? value, {int maximum = folderSyncMaxSequence}) {
  if (value is! int || value < 1 || value > maximum) {
    throw const FormatException('Invalid sync integer');
  }
  return value;
}

bool isSyncDigest(String value) => RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

final class SyncCollectionId {
  SyncCollectionId({
    required String publisher,
    required this.kind,
    required String source,
  }) : publisher = syncUuid(publisher),
       source = syncUuid(source) {
    if (!syncSourceKinds.contains(kind)) {
      throw const SyncUpdateRequired();
    }
  }

  factory SyncCollectionId.fromJson(Map<String, dynamic> json) =>
      SyncCollectionId(
        publisher: syncUuid(json['publisher']),
        kind: syncString(json['kind']),
        source: syncUuid(json['source']),
      );

  final String publisher;
  final String kind;
  final String source;
  String get key => '$publisher/$kind/$source';
  String get directory => 'devices/$publisher/collections/$kind/$source';
  Map<String, Object> toJson() => {
    'publisher': publisher,
    'kind': kind,
    'source': source,
  };

  @override
  bool operator ==(Object other) =>
      other is SyncCollectionId &&
      other.publisher == publisher && other.kind == kind && other.source == source;
  @override
  int get hashCode => Object.hash(publisher, kind, source);
}

/// Private seed belongs only in app-local metadata, never the shared directory.
final class SyncSigningIdentity {
  SyncSigningIdentity({
    required String id,
    required List<int> seed,
    required List<int> publicKey,
  }) : id = syncUuid(id),
       seed = List<int>.unmodifiable(seed),
       publicKey = List<int>.unmodifiable(publicKey) {
    if (!_keyBytes(this.seed) || !_keyBytes(this.publicKey)) {
      throw const FormatException('Invalid signing key');
    }
  }

  factory SyncSigningIdentity.fromJson(Map<String, dynamic> json) =>
      SyncSigningIdentity(
        id: syncUuid(json['id']),
        seed: base64Decode(syncString(json['seed'])),
        publicKey: base64Decode(syncString(json['publicKey'])),
      );

  final String id;
  final List<int> seed;
  final List<int> publicKey;
  String get fingerprint => syncDigest(publicKey);

  static Future<SyncSigningIdentity> create() async {
    final key = await signing.Ed25519().newKeyPair();
    return SyncSigningIdentity(
      id: const Uuid().v4(),
      seed: await key.extractPrivateKeyBytes(),
      publicKey: (await key.extractPublicKey()).bytes,
    );
  }

  Map<String, Object> localJson() => {
    'id': id,
    'seed': base64Encode(seed),
    'publicKey': base64Encode(publicKey),
  };
  Map<String, Object> publicJson() => {
    'protocol': folderSyncProtocol,
    'id': id,
    'publicKey': base64Encode(publicKey),
  };

  Future<Uint8List> sign(Map<String, Object?> content) async {
    // Freeze the exact bytes before an asynchronous key operation. An editable
    // device display name belongs in signed catalogs, not immutable identity.json.
    final message = syncJsonBytes(content);
    if (message.length > folderSyncMaxMetadataBytes) {
      throw const FormatException('Sync metadata exceeds byte limit');
    }
    final keyPair = await signing.Ed25519().newKeyPairFromSeed(seed);
    final derived = (await keyPair.extractPublicKey()).bytes;
    if (base64Encode(derived) != base64Encode(publicKey)) {
      throw const FormatException('Signing identity key mismatch');
    }
    final signature = await signing.Ed25519().sign(message, keyPair: keyPair);
    final envelope = syncJsonBytes({
      'content': decodeSyncObject(message),
      'signature': base64Encode(signature.bytes),
    });
    if (envelope.length > folderSyncMaxMetadataBytes) {
      throw const FormatException('Signed sync metadata exceeds byte limit');
    }
    return envelope;
  }
}

bool _keyBytes(List<int> bytes) =>
    bytes.length == 32 && bytes.every((byte) => byte >= 0 && byte <= 255);

Future<Map<String, dynamic>> verifySyncDocument(
  List<int> bytes,
  List<int> publicKey,
) async {
  final key = List<int>.unmodifiable(publicKey);
  final envelope = decodeSyncObject(bytes);
  final content = envelope['content'];
  final rawSignature = envelope['signature'];
  if (!_keyBytes(key) ||
      content is! Map<String, dynamic> || rawSignature is! String) {
    throw const FormatException('Invalid signed sync document');
  }
  final signatureBytes = base64Decode(rawSignature);
  if (signatureBytes.length != 64 ||
      !await signing.Ed25519().verify(
        syncJsonBytes(content),
        signature: signing.Signature(
          signatureBytes,
          publicKey: signing.SimplePublicKey(key, type: signing.KeyPairType.ed25519),
        ),
      )) {
    throw const FormatException('Sync signature verification failed');
  }
  if (content['protocol'] != folderSyncProtocol) {
    throw const SyncUpdateRequired();
  }
  return content;
}

final class SyncRevision {
  SyncRevision({
    required this.collection,
    required this.revision,
    required this.length,
    required this.sha256,
    required this.semanticHash,
    required this.schema,
  }) {
    syncPositiveInteger(revision);
    syncPositiveInteger(length, maximum: folderSyncMaxBytes);
    syncPositiveInteger(schema);
    if (!isSyncDigest(sha256) || !isSyncDigest(semanticHash)) {
      throw const FormatException('Invalid sync revision digest');
    }
  }
  factory SyncRevision.fromJson(Map<String, dynamic> json) {
    if (json['protocol'] != folderSyncProtocol) throw const SyncUpdateRequired();
    return SyncRevision(
      collection: SyncCollectionId.fromJson(json),
      revision: syncPositiveInteger(json['revision']),
      length: syncPositiveInteger(json['length'], maximum: folderSyncMaxBytes),
      sha256: syncString(json['sha256']),
      semanticHash: syncString(json['semanticHash']),
      schema: syncPositiveInteger(json['schema']),
    );
  }
  final SyncCollectionId collection;
  final int revision;
  final int length;
  final String sha256;
  final String semanticHash;
  final int schema;
  String get payloadPath => '${collection.directory}/$revision.bsexport';
  String get descriptorPath => '${collection.directory}/$revision.json';
  Map<String, Object?> toJson() => {
    'protocol': folderSyncProtocol,
    ...collection.toJson(),
    'revision': revision,
    'length': length,
    'sha256': sha256,
    'semanticHash': semanticHash,
    'schema': schema,
  };
  void verifyPayload(List<int> bytes) {
    if (bytes.length != length || syncDigest(bytes) != sha256) {
      throw const FormatException('Sync payload verification failed');
    }
  }
}

final class SyncUpdateRequired implements Exception {
  const SyncUpdateRequired();
}
final class SyncConflict implements Exception {
  const SyncConflict();
}
final class SyncProfileRequired implements Exception {
  const SyncProfileRequired();
}
final class SyncTrustRequired implements Exception {
  const SyncTrustRequired();
}
final class SyncReplayRejected implements Exception {
  const SyncReplayRejected();
}
