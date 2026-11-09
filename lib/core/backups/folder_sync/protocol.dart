import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as signing;
import 'package:uuid/uuid.dart';

import 'storage.dart';

const folderSyncProtocol = 1;
const syncSourceKinds = {'bookmarks', 'following_topics'};

String canonicalSyncJson(Object? value) => jsonEncode(_canonical(value));
Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is Iterable) return value.map(_canonical).toList();
  return value;
}

Uint8List syncJsonBytes(Object? value) =>
    Uint8List.fromList(utf8.encode(canonicalSyncJson(value)));
String syncDigest(List<int> bytes) => sha256.convert(bytes).toString();

Map<String, dynamic> decodeSyncObject(
  List<int> bytes, {
  int maximum = 256 * 1024,
}) {
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

final class SyncCollectionId {
  SyncCollectionId({
    required String publisher,
    required this.kind,
    required String source,
  }) : publisher = syncUuid(publisher),
       source = syncUuid(source) {
    if (!syncSourceKinds.contains(kind)) {
      throw const FormatException('Unsupported sync collection kind');
    }
  }
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
}

final class SyncSigningIdentity {
  SyncSigningIdentity({
    required this.id,
    required this.seed,
    required this.publicKey,
  });

  factory SyncSigningIdentity.fromJson(Map<String, dynamic> json) {
    final seed = base64Decode(json['seed'] as String);
    final publicKey = base64Decode(json['publicKey'] as String);
    if (seed.length != 32 || publicKey.length != 32) {
      throw const FormatException('Invalid signing key');
    }
    return SyncSigningIdentity(
      id: syncUuid(json['id']),
      seed: seed,
      publicKey: publicKey,
    );
  }
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
    final keyPair = await signing.Ed25519().newKeyPairFromSeed(seed);
    final signature = await signing.Ed25519().sign(
      syncJsonBytes(content),
      keyPair: keyPair,
    );
    return syncJsonBytes({
      'content': content,
      'signature': base64Encode(signature.bytes),
    });
  }
}

Future<Map<String, dynamic>> verifySyncDocument(
  List<int> bytes,
  List<int> publicKey,
) async {
  final envelope = decodeSyncObject(bytes);
  final content = envelope['content'];
  final rawSignature = envelope['signature'];
  if (publicKey.length != 32 ||
      content is! Map<String, dynamic> ||
      rawSignature is! String) {
    throw const FormatException('Invalid signed sync document');
  }
  final signatureBytes = base64Decode(rawSignature);
  if (signatureBytes.length != 64 ||
      !await signing.Ed25519().verify(
        syncJsonBytes(content),
        signature: signing.Signature(
          signatureBytes,
          publicKey: signing.SimplePublicKey(
            publicKey,
            type: signing.KeyPairType.ed25519,
          ),
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
    if (revision < 1 ||
        revision > 9007199254740991 ||
        length < 1 ||
        length > folderSyncMaxBytes ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(semanticHash)) {
      throw const FormatException('Invalid sync revision');
    }
  }
  factory SyncRevision.fromJson(Map<String, dynamic> json) => SyncRevision(
    collection: SyncCollectionId(
      publisher: json['publisher'] as String,
      kind: json['kind'] as String,
      source: json['source'] as String,
    ),
    revision: json['revision'] as int,
    length: json['length'] as int,
    sha256: json['sha256'] as String,
    semanticHash: json['semanticHash'] as String,
    schema: json['schema'] as int,
  );
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
