import '../../../../../foundation/data_mutation_coordinator.dart';
import '../../../selected_tags/types.dart';
import '../types/search_history.dart';
import '../types/search_history_repository.dart';

final class CoordinatedSearchHistoryRepository
    implements SearchHistoryRepository {
  const CoordinatedSearchHistoryRepository(this.delegate, this.coordinator);

  final SearchHistoryRepository delegate;
  final DataMutationCoordinator coordinator;

  @override
  Future<List<SearchHistory>> addHistory(
    String query, {
    required QueryType queryType,
    required String booruTypeName,
    required String siteUrl,
  }) => coordinator.runExclusive(
    () => delegate.addHistory(
      query,
      queryType: queryType,
      booruTypeName: booruTypeName,
      siteUrl: siteUrl,
    ),
  );

  @override
  Future<bool> clearAll() => coordinator.runExclusive(delegate.clearAll);

  @override
  Future<List<SearchHistory>> getHistories() => delegate.getHistories();

  @override
  Future<List<SearchHistory>> removeHistory(SearchHistory history) =>
      coordinator.runExclusive(() => delegate.removeHistory(history));
}
