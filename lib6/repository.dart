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

  /// Помечает все страницы как устаревшие (для refresh)
  Future<void> invalidate(Filter filter) async {
    await _cache.markAllPagesStale(filter);
    _touch(filter); // уведомляем подписчиков
  }

  Future<Stream<TaskListData>> fetch(
    Filter filter, {
    required int offset,
    required int limit,
    bool force = false,
    int pageSize = 10,
  }) async {
    print('[TaskRepository] fetch $filter offset: $offset, limit: $limit, force: $force');

    if (force) {
      await _cache.deleteGroup(filter);
    }

    final fromCache = await _cache.fetch(
      groupKey: filter,
      offset: offset,
      limit: limit,
    );

    if (force) {
      // При force загружаем весь запрашиваемый диапазон
      print('[TaskRepository] Force loading from API: $offset count: $limit');
      final tasks = await _api.getTasks(
        filter: filter,
        offset: offset,
        limit: limit,
      );
      
      await _cache.upsertTasks(
        groupKey: filter,
        from: offset,
        tasks: tasks,
        pageSize: pageSize,
      );

      await _cache.updateTotalFromPageIfFrontier(
        filter: filter,
        pageOffset: offset,
        requested: limit,
        received: tasks.length,
      );
    } else {
      // Загружаем только недостающие/устаревшие страницы
      for (var pageOffset = offset; pageOffset < offset + limit; pageOffset += pageSize) {
        final cachedPage = await _cache.fetch(
          groupKey: filter, 
          offset: pageOffset, 
          limit: pageSize
        );
        
        final isStale = await _cache.isPageStale(filter, pageOffset, pageSize);
        final needsData = cachedPage.length < pageSize;
        
        if (isStale || needsData) {
          print('[TaskRepository] Loading page from API: $pageOffset (stale: $isStale, needs: $needsData)');
          final tasks = await _api.getTasks(
            filter: filter,
            offset: pageOffset,
            limit: pageSize,
          );
          
          await _cache.upsertTasks(
            groupKey: filter,
            from: pageOffset,
            tasks: tasks,
            pageSize: pageSize,
          );

          await _cache.updateTotalFromPageIfFrontier(
            filter: filter,
            pageOffset: pageOffset,
            requested: pageSize,
            received: tasks.length,
          );
          
          // Если получили меньше чем pageSize - это последняя страница
          if (tasks.length < pageSize) {
            break;
          }
        }
      }
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
