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

  // Управляем чанками и стримом для каждого фильтра
  final Map<Filter, _ChunkManager> _managers = {};

  /// Получить или создать ChunkManager для фильтра
  _ChunkManager _getManager(Filter filter) {
    return _managers.putIfAbsent(filter, () => _ChunkManager(
      filter: filter,
      api: _api,
      cache: _cache,
    ));
  }

  /// Инициализация - загрузка первой страницы
  Future<Stream<TaskListData>> init(Filter filter, {required int pageSize}) async {
    final manager = _getManager(filter);
    await manager.init(pageSize);
    return manager.stream;
  }

  /// Загрузить следующую страницу
  Future<void> loadMore(Filter filter) async {
    final manager = _getManager(filter);
    await manager.loadMore();
  }

  /// Обновить данные - помечаем как stale и перезагружаем первую страницу
  Future<void> refresh(Filter filter) async {
    final manager = _getManager(filter);
    await manager.refresh();
  }

  Future<void> update(TaskModel model) async {
    await _api.update(model);
    await _cache.updateEntity(model);
    
    // Уведомляем все менеджеры об изменении
    for (final manager in _managers.values) {
      await manager.onEntityUpdated(model);
    }
  }

  Future<void> delete(TaskModel model) async {
    await _api.delete(model);
    await _cache.deleteEntity(model.id);
    
    // Уведомляем все менеджеры об удалении
    for (final manager in _managers.values) {
      await manager.onEntityDeleted(model);
    }
  }
}

class _ChunkManager {
  _ChunkManager({
    required this.filter,
    required this.api,
    required this.cache,
  });

  final Filter filter;
  final TaskApi api;
  final TasksCache cache;

  int _pageSize = 10;
  int _currentPage = 0;
  
  final _data$ = BehaviorSubject<TaskListData>();
  Stream<TaskListData> get stream => _data$.stream;

  /// Инициализация
  Future<void> init(int pageSize) async {
    _pageSize = pageSize;
    _currentPage = 0;
    await cache.markGroupFresh(filter);
    await _loadPage(0);
  }

  /// Загрузить следующую страницу
  Future<void> loadMore() async {
    final currentData = _data$.value;
    if (currentData.total != null && currentData.tasks.length >= currentData.total!) {
      return; // больше данных нет
    }
    
    _currentPage++;
    await _loadPage(_currentPage);
  }

  /// Обновление - помечаем stale и загружаем первую страницу
  Future<void> refresh() async {
    await cache.markGroupStale(filter);
    await _loadPage(0);
    
    // Обновляем только первую страницу, остальные останутся в кэше
    // При следующих loadMore() они будут проверены на staleness
  }

  /// Загрузить конкретную страницу
  Future<void> _loadPage(int page) async {
    final offset = page * _pageSize;
    final isStale = await cache.isGroupStale(filter);
    
    // Если данные устарели или их нет в кэше - загружаем с API
    final fromCache = await cache.fetch(
      groupKey: filter,
      offset: offset,
      limit: _pageSize,
    );
    
    if (isStale || fromCache.length < _pageSize) {
      print('[ChunkManager] Loading page $page from API (stale: $isStale)');
      final tasks = await api.getTasks(
        filter: filter,
        offset: offset,
        limit: _pageSize,
      );
      
      await cache.upsertTasks(
        groupKey: filter,
        from: offset,
        tasks: tasks,
      );
      
      // Если это первая страница после staleness - помечаем группу как свежую
      if (isStale && page == 0) {
        await cache.markGroupFresh(filter);
      }
      
      await cache.updateTotalFromPageIfFrontier(
        filter: filter,
        pageOffset: offset,
        requested: _pageSize,
        received: tasks.length,
      );
    }
    
    // Получаем актуальные данные и эмитим
    await _emitCurrentData();
  }

  /// Собираем все загруженные данные и эмитим в стрим
  Future<void> _emitCurrentData() async {
    final allTasks = <TaskModel>[];
    var offset = 0;
    
    // Собираем все непрерывные данные начиная с 0
    while (true) {
      final chunk = await cache.fetch(
        groupKey: filter,
        offset: offset,
        limit: _pageSize,
      );
      
      if (chunk.isEmpty) break;
      allTasks.addAll(chunk);
      offset += chunk.length;
      
      // Если получили меньше чем pageSize - значит это последний чанк
      if (chunk.length < _pageSize) break;
    }
    
    final total = await cache.getTotal(filter);
    _data$.add(TaskListData(tasks: allTasks, total: total));
  }

  /// Обработка обновления сущности
  Future<void> onEntityUpdated(TaskModel model) async {
    await _emitCurrentData(); // пересобираем данные
  }

  /// Обработка удаления сущности  
  Future<void> onEntityDeleted(TaskModel model) async {
    await _emitCurrentData(); // пересобираем данные
  }
}