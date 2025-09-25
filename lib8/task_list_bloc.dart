import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'filter_model.dart';
import 'task_model.dart';
import 'task_repository.dart';

class TaskListState {
  TaskListState({
    required this.tasks,
    required this.hasMore,
    required this.isLoading,
  });

  final List<TaskModel> tasks;
  final bool hasMore;
  final bool isLoading;

  TaskListState copyWith({
    List<TaskModel>? tasks,
    bool? hasMore,
    bool? isLoading,
  }) {
    return TaskListState(
      tasks: tasks ?? this.tasks,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class TaskListBloc {
  TaskListBloc({required this.filter});

  final Filter filter;

  final TaskRepository _repo = TaskRepository.instance;

  final _state$ = BehaviorSubject<TaskListState>.seeded(
      TaskListState(tasks: [], hasMore: true, isLoading: false));

  final _limit = 10;

  Stream<TaskListState> get state$ => _state$.stream;

  TaskListState get state => _state$.value;

  bool forceAfterRefresh = false;

  Future<void> init() async {
    await loadData(offset: 0, limit: _limit);
    _repo.onChanged$.asyncMap((_) async {
      final currentLength = state.tasks.length;
      if (currentLength > 0) {
        final data = await _repo.fetch(
          filter,
          offset: 0,
          limit: state.tasks.length,
          onlyCache: true,
        );

        _state$.add(state.copyWith(tasks: data, hasMore: true));
      }
    }).listen((_) {});
  }

  Future<void> setCompleted(int id, bool isCompleted) async {
    _state$.add(state.copyWith(isLoading: true));
    await _repo.update(UpdateTaskCompleted(
      id: id,
      isCompleted: isCompleted,
    ));
    _state$.add(state.copyWith(isLoading: false));
  }

  Future<void> delete(TaskModel task) async {
    _state$.add(state.copyWith(isLoading: true));
    await _repo.delete(task);
    _state$.add(state.copyWith(isLoading: false));
  }

  Future<void> loadMore() async {
    if (!state.hasMore) return;
    final currentLength = state.tasks.length;
    await loadData(offset: currentLength, limit: _limit);
  }

  Future<void> refresh() async {
    _state$.add(state.copyWith(tasks: [], hasMore: true));
    forceAfterRefresh = true;
    await loadData(offset: 0, limit: _limit);
  }

  Future<void> loadData({
    required int offset,
    required int limit,
  }) async {
    _state$.add(state.copyWith(isLoading: true));

    final result = await _repo.fetch(
      filter,
      offset: offset,
      limit: limit,
      force: forceAfterRefresh,
    );

    _state$.add(
      state.copyWith(
        tasks: [...state.tasks, ...result],
        isLoading: false,
        hasMore: !(result.length < limit),
      ),
    );
  }
}
