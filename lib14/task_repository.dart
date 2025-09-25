import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'model/filter_model.dart';
import 'main.dart';
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

  final _patch$ = PublishSubject<TaskPatch>();

  Future<Stream<TaskDetailsModel>> getTaskDetailsStream(int id) async {
    final subj = BehaviorSubject<TaskDetailsModel>();

    // 1) один сетевой запрос при подписке
    subj.add(await _api.getTask(id));

    // 2) подмешиваем патчи: патчим только пересекающиеся поля
    final sub = _patch$.where((p) => p.id == id).listen((p) {
      final cur = subj.valueOrNull;
      if (cur != null) {
        subj.add(cur.copyWith(
          isCompleted: p.isCompleted ?? cur.isCompleted,
        ));
      }
    });

    return subj.stream.doOnCancel(() async {
      await sub.cancel();
      await subj.close();
    });
  }

  Future<void> setCompleted(int id, bool isCompleted) async {
    await _api.setCompleted(isCompleted: isCompleted, id: id);

    final patch = TaskPatch(id: id, isCompleted: isCompleted);

    _patch$.add(patch);

    await _cache.applyPatch(patch);
  }

  Stream<List<TaskModel>> getTasksStream(Filter filter, int offset, int limit) {
    return _cache.getTasksStream(
      filter,
      offset: offset,
      limit: limit,
    );
  }

  Future<void> update(TaskModel model) async {
    await _cache.update(model);
  }

  Future<void> delete(TaskModel model) async {
    await _api.delete(model);

    await _cache.delete(model.id);
  }
}
