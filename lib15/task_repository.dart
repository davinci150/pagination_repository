import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'model/filter_model.dart';
import 'main.dart';
import 'model/task_entity.dart';
import 'task_api.dart';
import 'task_cache.dart';
import 'model/task_details_model.dart';
import 'model/task_model.dart';

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
        tasks: _mapTaskEntityList(fromApi),
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
        tasks: _mapTaskEntityList(fromApi),
      );

      return _mapTaskModelList(
        await _cache.fetch(
          groupKey: filter,
          offset: offset,
          limit: limit,
        ),
      );
    }

    return _mapTaskModelList(fromCache);
  }

  List<TaskEntity> _mapTaskEntityList(List<TaskModel> tasks) {
    return tasks.map((e) => TaskEntity.fromTaskModel(e)).toList();
  }

  List<TaskModel> _mapTaskModelList(List<TaskEntity> tasks) {
    return tasks
        .map((e) =>
            TaskModel(id: e.id, isCompleted: e.isCompleted, title: e.title))
        .toList();
  }

  Future<Stream<TaskDetailsModel>> getTaskDetailsStream(int id) async {
    final subj = BehaviorSubject<TaskDetailsModel>();

    subj.add(await _api.getTask(id));

    final sub = _cache.getTaskStream(id).whereNotNull().listen((entity) {
      final cur = subj.valueOrNull;
      if (cur != null) {
        subj.add(cur.updateFromEntity(entity));
      }
    });

    return subj.stream.doOnCancel(() async {
      await sub.cancel();
      await subj.close();
    });
  }

  Stream<List<TaskModel>> watchTasks(Filter filter, int offset, int limit) {
    return _cache
        .getTasksStream(
          filter,
          offset: offset,
          limit: limit,
        )
        .map((e) => _mapTaskModelList(e));
  }

  Future<void> setCompleted(
      {required int id, required bool isCompleted}) async {
    await _api.setCompleted(isCompleted: isCompleted, id: id);
    await _cache.applyPatch(TaskPatch(id: id, isCompleted: isCompleted));
  }

  Future<void> delete(int id) async {
    await _api.delete(id);

    await _cache.delete(id);
  }
}
