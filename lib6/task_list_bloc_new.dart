import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'filter_model.dart';
import 'repository_new.dart';
import 'task_list_data.dart';
import 'task_model.dart';

class TaskListBloc {
  TaskListBloc({required this.filter});

  final Filter filter;

  final TaskRepository _repo = TaskRepository.instance;

  final _progress$ = BehaviorSubject<bool>();

  final pageSize = 10;

  late final Stream<TaskListData> _tasks$;
  Stream<TaskListData> get tasks$ => _tasks$;
  Stream<bool> get progress$ => _progress$.stream;

  Future<void> init() async {
    print('[TaskListBloc] init');
    _progress$.add(true);
    _tasks$ = await _repo.init(filter, pageSize: pageSize);
    _progress$.add(false);
  }

  Future<void> setCompleted(int id, bool isCompleted) async {
    _progress$.add(true);
    // Ищем задачу среди всех загруженных
    final currentData = await _tasks$.first;
    final task = currentData.tasks.firstWhere((e) => e.id == id);
    await _repo.update(task.copyWith(isCompleted: isCompleted));
    _progress$.add(false);
  }

  Future<void> loadMore() async {
    print('[TaskListBloc] loadMore');
    _progress$.add(true);
    await _repo.loadMore(filter);
    _progress$.add(false);
  }

  Future<void> refresh() async {
    print('[TaskListBloc] refresh');
    _progress$.add(true);
    await _repo.refresh(filter);
    _progress$.add(false);
  }

  void dispose() {
    _progress$.close();
  }
}