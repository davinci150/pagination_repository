import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'filter_model.dart';
import 'task_api.dart';
import 'task_cache.dart';
import 'task_list_data.dart';
import 'task_model.dart';

class TaskRepository {
  TaskRepository._();

  static final TaskRepository _instance = TaskRepository._();

  static TaskRepository get instance => _instance;

  final TaskApi _api = TaskApi.instance;

  final _cache = TasksCache();

  /// Простая шина событий: «в группе X кэш обновился»
  final PublishSubject<Filter> _touch$ = PublishSubject<Filter>();

  /// Самый простой способ «заставить все страницы группы перечитать кэш»
  void _touch(Filter filter) => _touch$.add(filter);

  Future<Stream<TaskListData>> fetch(
    Filter filter, {
    required int offset,
    required int limit,
    bool force = false,
    bool partialForce = false,
  }) async {
    print('[TaskRepository] fetch $filter with force: $force, partialForce: $partialForce');

    if (force) {
      await _cache.deleteGroup(filter);
    } else if (partialForce) {
      // Частичное обновление: очищаем только запрашиваемый диапазон
      await _cache.clearRange(
        groupKey: filter,
        offset: offset,
        limit: limit,
      );
    }

    final fromCache = await _cache.fetch(
      groupKey: filter,
      offset: offset,
      limit: limit,
    );

    // При partialForce принудительно загружаем запрашиваемый диапазон с API
    if (partialForce || fromCache.length < limit) {
      final missingFrom = partialForce ? offset : offset + fromCache.length;
      final fetchLimit = partialForce ? limit : limit - fromCache.length;
      print('[TaskRepository] missingFrom: $missingFrom count: $fetchLimit');
      final tasks = await _api.getTasks(
        filter: filter,
        offset: missingFrom,
        limit: fetchLimit,
      );
      await _cache.upsertTasks(
        groupKey: filter,
        from: missingFrom,
        tasks: tasks,
      );

      await _cache.updateTotalFromPageIfFrontier(
        filter: filter,
        pageOffset: missingFrom,
        requested: fetchLimit,
        received: tasks.length,
      );
    }

    final initialSlice = await _cache.fetch(
      groupKey: filter,
      offset: offset,
      limit: limit,
    );
    final initialTotal = await _cache.getTotal(filter);

    final stream = _touch$.where((gk) => gk == filter).asyncMap((_) async {
      final data = await _cache.fetch(
        groupKey: filter,
        offset: offset,
        limit: limit,
      );
      final total = await _cache.getTotal(filter);
      return TaskListData(tasks: data, total: total);
    }).startWith(TaskListData(tasks: initialSlice, total: initialTotal));

    return stream;
  }

  Future<void> update(TaskModel model) async {
    await _api.update(model);

    await _cache.updateEntity(model);

    for (final groupKey in _cache.groupKeys) {
      _touch(groupKey);
    }
  }

  Future<void> delete(TaskModel model) async {
    await _api.delete(model);

    await _cache.deleteEntity(model.id);

    for (final groupKey in _cache.groupKeys) {
      _touch(groupKey);
    }
  }
}
