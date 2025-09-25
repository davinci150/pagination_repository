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
    }).listen((_) {});
  }

  static final TaskRepository _instance = TaskRepository._();

  static TaskRepository get instance => _instance;

  final TaskApi _api = TaskApi.instance;

  final _cache = TasksCache();

  final Map<int, BehaviorSubject<TaskDetailsModel>> _taskDetailsStreams = {};

  Future<Stream<TaskDetailsModel>> getTaskDetailsStream(int taskId) async {
    if (!_taskDetailsStreams.containsKey(taskId)) {
      final task = await _api.getTask(taskId);
      _taskDetailsStreams.putIfAbsent(
        taskId,
        () => BehaviorSubject<TaskDetailsModel>.seeded(
          task,
          onCancel: () {
            _taskDetailsStreams[taskId]!.close();
            _taskDetailsStreams.remove(taskId);
          },
        ),
      );
    }
    return _taskDetailsStreams[taskId]!.stream;
  }

  Future<List<TaskModel>> getTasks(
    Filter filter, {
    required int offset,
    required int limit,
    bool force = false,
  }) async {
    print('[TaskRepository] fetch $filter with force: $force');

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

  Stream<List<TaskModel>> getTasksStream(Filter filter, int offset, int limit) {
    return _cache.getTasksStream(
      filter,
      offset: offset,
      limit: limit,
    );
  }

  Future<void> setCompleted(int id, bool isCompleted) async {
    await _api.setCompleted(id: id, isCompleted: isCompleted);

    final model = await _cache.getById(id);
    if (model != null) {
      await _cache.update(model.copyWith(isCompleted: isCompleted));
    }

    if (_taskDetailsStreams.containsKey(id)) {
      final model = _taskDetailsStreams[id]!.value;
      _taskDetailsStreams[id]!.add(
        model.copyWith(isCompleted: isCompleted),
      );
    }
  }

  Future<void> delete(TaskModel model) async {
    await _api.delete(model);

    await _cache.delete(model.id);
  }
}
