import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'filter_model.dart';
import 'main.dart';
import 'task_api.dart';
import 'task_cache.dart';
import 'task_details_model.dart';
import 'task_model.dart';

class TaskRepository {
  TaskRepository._() {
    invalidateCache$.asyncMap((_) async {
      await _cache.clear();
      _touch(true);
    }).listen((_) {});
  }

  static final TaskRepository _instance = TaskRepository._();

  static TaskRepository get instance => _instance;

  final TaskApi _api = TaskApi.instance;

  final _cache = TasksCache();

  final _touch$ = PublishSubject<bool>();

  Stream<bool> get onChanged$ => _touch$.stream;

  void _touch(bool force) => _touch$.add(force);

  Future<List<TaskModel>> fetch(
    Filter filter, {
    required int offset,
    required int limit,
    bool force = false,
    bool onlyCache = false,
  }) async {
    print('[TaskRepository] fetch $filter with force: $force');

    if (onlyCache) {
      return _cache.fetch(
        groupKey: filter,
        offset: offset,
        limit: limit,
      );
    }

    if (force) {
      final fromApi = await _api.getTasks(
        filter: filter,
        offset: offset,
        limit: limit,
      );

      await _cache.addAll(
        groupKey: filter,
        from: offset,
        tasks: fromApi,
      );

      return fromApi;
    }

    final fromCache = await _cache.fetch(
      groupKey: filter,
      offset: offset,
      limit: limit,
    );

    if (fromCache.length < limit) {
      final missingFrom = offset + fromCache.length;
      final fetchLimit = limit - fromCache.length;

      print('[TaskRepository] missingFrom: $missingFrom count: $fetchLimit');

      final fromApi = await _api.getTasks(
        filter: filter,
        offset: missingFrom,
        limit: fetchLimit,
      );

      await _cache.addAll(
        groupKey: filter,
        from: missingFrom,
        tasks: fromApi,
      );

      return await _cache.fetch(
        groupKey: filter,
        offset: offset,
        limit: limit,
      );
    }

    return fromCache;
  }

  Future<TaskDetailsModel> fetchById(int id) async {
    final task = await _api.getTask(id);
    return task;
  }

  Future<void> update(UpdateTask updateTask) async {
    switch (updateTask) {
      case UpdateTaskCompleted():
        await _api.setCompleted(
          id: updateTask.id,
          isCompleted: updateTask.isCompleted,
        );

        final model = await _cache.getById(updateTask.id);
        if (model == null) return;

        await _cache.update(
          model.copyWith(isCompleted: updateTask.isCompleted),
        );

        _touch(true);
    }
  }

  Future<void> delete(TaskModel model) async {
    await _api.delete(model);

    await _cache.delete(model.id);

    _touch(true);
  }
}

abstract class UpdateTask {}

class UpdateTaskCompleted extends UpdateTask {
  final int id;
  final bool isCompleted;

  UpdateTaskCompleted({
    required this.id,
    required this.isCompleted,
  });
}
