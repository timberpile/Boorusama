import '../types/types.dart';

void requireSearchBackupEnvelope(ExportDataPayload payload, String sourceId) {
  if (payload.version != 1) {
    throw InvalidBackupFormatException(
      'Unsupported $sourceId backup version',
    );
  }
  if (payload.extraFields['source'] != sourceId) {
    throw InvalidBackupFormatException('Expected $sourceId backup source');
  }
}
