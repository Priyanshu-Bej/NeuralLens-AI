import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/script_repository.dart';
import '../models/script.dart';
import '../models/script_enums.dart';

enum LibraryFilter {
  all('All'),
  scripts('Scripts'),
  notes('Notes'),
  favorites('Favorites');

  const LibraryFilter(this.label);
  final String label;
}

enum LoadStatus { loading, ready, failure }

class LibraryState extends Equatable {
  const LibraryState({
    this.status = LoadStatus.loading,
    this.scripts = const [],
    this.query = '',
    this.filter = LibraryFilter.all,
  });

  final LoadStatus status;

  /// Every saved item, most recently updated first.
  final List<Script> scripts;
  final String query;
  final LibraryFilter filter;

  List<Script> get visible =>
      filterScripts(scripts, query: query, filter: filter);

  LibraryState copyWith({
    LoadStatus? status,
    List<Script>? scripts,
    String? query,
    LibraryFilter? filter,
  }) => LibraryState(
    status: status ?? this.status,
    scripts: scripts ?? this.scripts,
    query: query ?? this.query,
    filter: filter ?? this.filter,
  );

  @override
  List<Object?> get props => [status, scripts, query, filter];
}

/// Case-insensitive search across title, body and tags, plus a kind filter.
List<Script> filterScripts(
  List<Script> scripts, {
  String query = '',
  LibraryFilter filter = LibraryFilter.all,
}) {
  final q = query.trim().toLowerCase();
  return scripts.where((s) {
    final matchesFilter = switch (filter) {
      LibraryFilter.all => true,
      LibraryFilter.scripts => s.kind == ScriptKind.script,
      LibraryFilter.notes => s.kind == ScriptKind.note,
      LibraryFilter.favorites => s.isFavorite,
    };
    if (!matchesFilter) return false;
    if (q.isEmpty) return true;
    return s.title.toLowerCase().contains(q) ||
        s.body.toLowerCase().contains(q) ||
        s.tags.any((t) => t.toLowerCase().contains(q));
  }).toList();
}

/// App-wide view of the local library, shared by Home and Library.
class LibraryCubit extends Cubit<LibraryState> {
  LibraryCubit(this._repository) : super(const LibraryState()) {
    _sub = _repository.changes.listen((_) => load());
  }

  final ScriptRepository _repository;
  late final StreamSubscription<void> _sub;

  Future<void> load() async {
    try {
      final scripts = await _repository.getAll();
      if (!isClosed) {
        emit(state.copyWith(status: LoadStatus.ready, scripts: scripts));
      }
    } catch (_) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure));
    }
  }

  void search(String query) => emit(state.copyWith(query: query));

  void setFilter(LibraryFilter filter) => emit(state.copyWith(filter: filter));

  Future<void> toggleFavorite(Script script) =>
      _repository.setFavorite(script.id, favorite: !script.isFavorite);

  Future<Script?> duplicate(Script script) => _repository.duplicate(script.id);

  Future<void> delete(Script script) => _repository.delete(script.id);

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
