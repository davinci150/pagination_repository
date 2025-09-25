import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'filter_model.dart';
import 'main.dart';
import 'task_api.dart';
import 'task_cache.dart';
import 'task_details_model.dart';
import 'task_model.dart';

class TaskRepository implements TaskRepositoryI {
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

  @override
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

  @override
  Future<List<TaskModel>> fetchTasks(
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

  @override
  Stream<List<TaskModel>> getTasksStream(Filter filter, int offset, int limit) {
    return _cache.getTasksStream(
      filter,
      offset: offset,
      limit: limit,
    );
  }

  @override
  Future<void> setCompleted(int id, bool isCompleted) async {
    await _api.setCompleted(id: id, isCompleted: isCompleted);

    await _cache.applyPatch(TaskPatch(id: id, isCompleted: isCompleted));

    if (_taskDetailsStreams.containsKey(id)) {
      final model = _taskDetailsStreams[id]!.value;
      _taskDetailsStreams[id]!.add(
        model.copyWith(isCompleted: isCompleted),
      );
    }
  }

  @override
  Future<void> delete(TaskModel model) async {
    await _api.delete(model);

    await _cache.delete(model.id);
  }

  @override
  Future<TaskDetailsModel> getTaskDetails(int taskId) {
    return _api.getTask(taskId);
  }
}

abstract class TaskRepositoryI {
  Future<List<TaskModel>> fetchTasks(
    Filter filter, {
    required int offset,
    required int limit,
    bool force = false,
  });

  Stream<List<TaskModel>> getTasksStream(Filter filter, int offset, int limit);

  Future<Stream<TaskDetailsModel>> getTaskDetailsStream(int taskId);

  Future<TaskDetailsModel> getTaskDetails(int taskId);

  Future<void> setCompleted(int id, bool isCompleted);

  Future<void> delete(TaskModel model);
}
