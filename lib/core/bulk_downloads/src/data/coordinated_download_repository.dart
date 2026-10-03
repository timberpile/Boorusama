import '../../../../foundation/data_mutation_coordinator.dart';
import '../../../configs/config/types.dart';
import '../types/bulk_download_session.dart';
import '../types/download_options.dart';
import '../types/download_record.dart';
import '../types/download_repository.dart';
import '../types/download_session.dart';
import '../types/download_session_stats.dart';
import '../types/download_task.dart';
import '../types/saved_download_task.dart';

final class CoordinatedDownloadRepository implements DownloadRepository {
  const CoordinatedDownloadRepository(this.delegate, this.coordinator);

  final DownloadRepository delegate;
  final DataMutationCoordinator coordinator;

  Future<T> _write<T>(Future<T> Function() operation) =>
      coordinator.runExclusive(operation);

  @override
  Future<void> completeSession(String id) =>
      _write(() => delegate.completeSession(id));

  @override
  Future<void> createRecord(DownloadRecord record) =>
      _write(() => delegate.createRecord(record));

  @override
  Future<void> createRecords(List<DownloadRecord> records) =>
      _write(() => delegate.createRecords(records));

  @override
  Future<SavedDownloadTask> createSavedTask(DownloadTask task, String name) =>
      _write(() => delegate.createSavedTask(task, name));

  @override
  Future<DownloadSession> createSession(
    DownloadTask task,
    BooruConfigAuth auth,
  ) => _write(() => delegate.createSession(task, auth));

  @override
  Future<DownloadTask> createTask(DownloadOptions options) =>
      _write(() => delegate.createTask(options));

  @override
  Future<void> deleteAllCompletedSessions() =>
      _write(delegate.deleteAllCompletedSessions);

  @override
  Future<void> deleteSavedTask(int id) =>
      _write(() => delegate.deleteSavedTask(id));

  @override
  Future<void> deleteSession(String id) =>
      _write(() => delegate.deleteSession(id));

  @override
  Future<void> deleteTask(String id) => _write(() => delegate.deleteTask(id));

  @override
  Future<void> editSavedTask(SavedDownloadTask task) =>
      _write(() => delegate.editSavedTask(task));

  @override
  Future<void> editTask(DownloadTask newTask) =>
      _write(() => delegate.editTask(newTask));

  @override
  Future<List<BulkDownloadSession>> getActiveSessions() =>
      delegate.getActiveSessions();

  @override
  Future<List<BulkDownloadSession>> getCompletedSessions({
    DateTime? startDate,
    DateTime? endDate,
    int offset = 0,
    int limit = 20,
  }) => delegate.getCompletedSessions(
    startDate: startDate,
    endDate: endDate,
    offset: offset,
    limit: limit,
  );

  @override
  Future<DownloadRecord?> getRecordByDownloadId(
    String sessionId,
    String downloadId,
  ) => delegate.getRecordByDownloadId(sessionId, downloadId);

  @override
  Future<List<DownloadRecord>> getRecordsBySessionId(
    String sessionId, {
    DownloadRecordStatus? status,
    int? recordPage,
  }) => delegate.getRecordsBySessionId(
    sessionId,
    status: status,
    recordPage: recordPage,
  );

  @override
  Future<List<DownloadRecord>> getRecordsBySessionIdAndStatuses(
    String sessionId,
    List<DownloadRecordStatus> statuses,
  ) => delegate.getRecordsBySessionIdAndStatuses(sessionId, statuses);

  @override
  Future<int> getRecordsCountBySessionId(
    String sessionId, {
    DownloadRecordStatus? status,
  }) => delegate.getRecordsCountBySessionId(sessionId, status: status);

  @override
  Future<SavedDownloadTask?> getSavedTask(int id) => delegate.getSavedTask(id);

  @override
  Future<List<SavedDownloadTask>> getSavedTasks() => delegate.getSavedTasks();

  @override
  Future<DownloadSession?> getSession(String id) => delegate.getSession(id);

  @override
  Future<List<DownloadSession>> getSessionsByStatus(
    DownloadSessionStatus status,
  ) => delegate.getSessionsByStatus(status);

  @override
  Future<List<DownloadSession>> getSessionsByStatuses(
    List<DownloadSessionStatus> statuses,
  ) => delegate.getSessionsByStatuses(statuses);

  @override
  Future<List<DownloadSession>> getSessionsByTaskId(String taskId) =>
      delegate.getSessionsByTaskId(taskId);

  @override
  Future<DownloadTask?> getTask(String id) => delegate.getTask(id);

  @override
  Future<List<DownloadTask>> getTasks() => delegate.getTasks();

  @override
  Future<List<DownloadTask>> getTasksByIds(List<String> ids) =>
      delegate.getTasksByIds(ids);

  @override
  Future<void> resetSessions(List<String> sessionIds) =>
      _write(() => delegate.resetSessions(sessionIds));

  @override
  Future<DownloadSessionStats> updateStatisticsAndCleanup(String sessionId) =>
      _write(() => delegate.updateStatisticsAndCleanup(sessionId));

  @override
  Future<void> updateRecord({
    required String url,
    required String sessionId,
    DownloadRecordStatus? status,
    int? fileSize,
    String? fileName,
    String? extension,
    String? error,
    String? downloadId,
  }) => _write(
    () => delegate.updateRecord(
      url: url,
      sessionId: sessionId,
      status: status,
      fileSize: fileSize,
      fileName: fileName,
      extension: extension,
      error: error,
      downloadId: downloadId,
    ),
  );

  @override
  Future<void> updateRecordByDownloadId({
    required String sessionId,
    required String downloadId,
    DownloadRecordStatus? status,
    int? fileSize,
    String? fileName,
    String? extension,
    String? error,
  }) => _write(
    () => delegate.updateRecordByDownloadId(
      sessionId: sessionId,
      downloadId: downloadId,
      status: status,
      fileSize: fileSize,
      fileName: fileName,
      extension: extension,
      error: error,
    ),
  );

  @override
  Future<void> updateRecordsByStatus(
    String sessionId, {
    required DownloadRecordStatus to,
    List<DownloadRecordStatus>? from,
  }) => _write(
    () => delegate.updateRecordsByStatus(sessionId, to: to, from: from),
  );

  @override
  Future<void> updateSession(
    String id, {
    DownloadSessionStatus? status,
    int? currentPage,
    int? totalPages,
    String? error,
  }) => _write(
    () => delegate.updateSession(
      id,
      status: status,
      currentPage: currentPage,
      totalPages: totalPages,
      error: error,
    ),
  );

  @override
  Future<void> updateSessionsStatus(
    List<String> sessionIds,
    DownloadSessionStatus status,
  ) => _write(() => delegate.updateSessionsStatus(sessionIds, status));
}
