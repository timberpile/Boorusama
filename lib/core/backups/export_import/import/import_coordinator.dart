import 'import_preflight.dart';
import 'import_transaction.dart';

final class ImportCoordinator {
  ImportCoordinator({
    required this.transaction,
    required this.sources,
    String Function()? transactionId,
  }) : _transactionId = transactionId ?? _defaultTransactionId;

  final ImportTransaction transaction;
  final Map<String, ImportTransactionSource> Function() sources;
  final String Function() _transactionId;
  Future<void> _tail = Future.value();

  Future<void> apply(ValidatedImportPlan plan) {
    final operation = _tail.then(
      (_) => transaction.execute(
        transactionId: _transactionId(),
        plan: plan,
        sources: sources(),
      ),
    );
    _tail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }
}

String _defaultTransactionId() =>
    DateTime.now().toUtc().microsecondsSinceEpoch.toString();
