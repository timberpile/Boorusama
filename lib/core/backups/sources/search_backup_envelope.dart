import '../types/types.dart';

class UnsupportedSearchBackupVersionException
    extends InvalidBackupFormatException {
  const UnsupportedSearchBackupVersionException(this.sourceId, this.version)
    : super('Unsupported $sourceId backup version');

  final String sourceId;
  final int version;
}

class WrongSearchBackupSourceException extends InvalidBackupFormatException {
  const WrongSearchBackupSourceException(
    this.expectedSourceId,
    this.actualSourceId,
  ) : super('Expected $expectedSourceId backup source');

  final String expectedSourceId;
  final Object? actualSourceId;
}

void requireSearchBackupEnvelope(ExportDataPayload payload, String sourceId) {
  if (payload.version != 1) {
    throw UnsupportedSearchBackupVersionException(sourceId, payload.version);
  }
  if (payload.extraFields['source'] != sourceId) {
    throw WrongSearchBackupSourceException(
      sourceId,
      payload.extraFields['source'],
    );
  }
}
