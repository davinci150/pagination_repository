import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'filter_model.dart';
import 'repository.dart';
import 'task_list_data.dart';
import 'task_model.dart';

class TaskListBloc {
  TaskListBloc({required this.filter});

  final Filter filter;

  final TaskRepository _repo = TaskRepository.instance;

  final _tasks$ = BehaviorSubject<TaskListData>();

  final _progress$ = BehaviorSubject<bool>();

  final limit = 10;

  Stream<TaskListData> get tasks$ => _tasks$.stream;
  Stream<bool> get progress$ => _progress$.stream;

  StreamSubscription? _subscription;

  Future<void> init() async {
    await getAndSubscribe(limit: limit);
  }

  Future<void> setCompleted(int id, bool isCompleted) async {
    _progress$.add(true);
    final task = _tasks$.value.tasks.firstWhere((e) => e.id == id);
    await _repo.update(task.copyWith(isCompleted: isCompleted));
    _progress$.add(false);
  }

  Future<void> loadMore() async {
    final currentLength = _tasks$.value.tasks.length;

    if (_tasks$.value.total == null || _tasks$.value.total! > currentLength) {
      getAndSubscribe(limit: currentLength + limit);
    }
  }

  Future<void> refresh() async {
    // НЕ очищаем данные в UI, обновляем только первую страницу
    await getAndSubscribe(limit: limit, partialForce: true);
  }

  Future<void> getAndSubscribe({
    required int limit,
    bool force = false,
    bool partialForce = false,
  }) async {
    print('[TaskListBloc] getAndSubscribe $limit');
    _progress$.add(true);
    final stream = await _repo.fetch(
      filter, 
      offset: 0, 
      limit: limit, 
      force: force,
      partialForce: partialForce,
    );
    _progress$.add(false);
    _subscription?.cancel();
    _subscription = stream.listen((listTasks) {
      _tasks$.add(listTasks);
    });
  }
}
