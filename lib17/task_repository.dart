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

      final updatedTime = DateTime.now();

      await _cache.addAll(
        groupKey: filter,
        from: offset,
        tasks: fromApi.map((e) {
          return CachedTaskModel(model: e, lastUpdated: updatedTime);
        }).toList(),
      );

      return fromApi;
    }

    List<CachedTaskModel> fromCache = await _cache.fetch(
      groupKey: filter,
      offset: offset,
      limit: limit,
    );

    int? staleIndex;
    for (int i = 0; i < fromCache.length; i++) {
      if (fromCache[i].isStale(TasksCache.ttl)) {
        staleIndex = i;
        break;
      }
    }

    if (staleIndex != null) {
      print('[TaskRepository] remove stale from $staleIndex to: ${fromCache.length}');

      fromCache = fromCache.sublist(0, staleIndex);
    }

    if (fromCache.length < limit) {
      final missingFrom = offset + fromCache.length;
      final fetchLimit = limit - fromCache.length;

      print('[TaskRepository] missingFrom: $missingFrom count: $fetchLimit');

      final fromApi = await _api.getTasks(
        filter: filter,
        offset: missingFrom,
        limit: fetchLimit,
      );

      final updatedTime = DateTime.now();

      await _cache.addAll(
        groupKey: filter,
        from: missingFrom,
        tasks: fromApi.map((e) {
          return CachedTaskModel(model: e, lastUpdated: updatedTime);
        }).toList(),
      );

      return _cache
          .fetch(
            groupKey: filter,
            offset: offset,
            limit: limit,
          )
          .then((e) => e.map((e) => e.model).toList());
    }

    return fromCache.map((e) => e.model).toList();
  }

  final _detailSubj = <int, BehaviorSubject<TaskDetailsModel>>{};

  Future<Stream<TaskDetailsModel>> getTaskDetailsStream(int id) async {
    final subj = _detailSubj.putIfAbsent(
      id,
      () => BehaviorSubject<TaskDetailsModel>(),
    );

    if (!subj.hasValue) subj.add(await _api.getTask(id));

    final sub = _entityPatchesCtrl.listen((entity) {
      final cur = subj.valueOrNull;
      if (cur != null) {
        subj.add(cur.updateFromPatch(entity));
      }
    });

    return subj.stream.doOnCancel(() {
      sub.cancel();
      _detailSubj[id]?.close();
      _detailSubj.remove(id);
    });
  }

  Stream<List<TaskModel>> watchTasks(Filter filter, int offset, int limit) {
    return _cache
        .getTasksStream(
          filter,
          offset: offset,
          limit: limit,
        )
        .map((e) => e.map((e) => e.model).toList());
  }

  final _entityPatchesCtrl = PublishSubject<TaskPatch>();

  Future<void> setCompleted(
      {required int id, required bool isCompleted}) async {
    await _api.setCompleted(isCompleted: isCompleted, id: id);
    final patch = TaskPatch(id: id, isCompleted: isCompleted);
    _entityPatchesCtrl.add(patch);
    await _cache.applyPatch(patch);
  }

  Future<void> delete(int id) async {
    await _api.delete(id);

    await _cache.delete(id);
  }
}

abstract class TasksRepositoryI {
  // LIST
  Future<List<TaskModel>> fetchTasks(Filter f,
      {required int offset, required int limit, bool force = false});
  Stream<List<TaskModel>> watchTasks(Filter f, int offset, int limit);

  // DETAILS (без долговременного кеша)
  Future<TaskDetailsModel> getTaskDetail(int id);
  Stream<TaskDetailsModel> watchTaskDetail(
      int id); // живой поток на время подписки

  // MUTATIONS (единая точка записи)
  Future<void> setCompleted({required int id, required bool isCompleted});
  Future<void> updateDescription(
      {required int id, required String description});
  Future<void> delete(int id);
}

class TaskDetailPatch {
  final int id;
  final String? description;
  const TaskDetailPatch({required this.id, this.description});
}
