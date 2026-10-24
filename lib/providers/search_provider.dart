import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the user has typed in the library search box.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);
