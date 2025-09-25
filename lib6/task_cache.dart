import 'filter_model.dart';
import 'task_model.dart';

class TasksCache {
  final Map<int, TaskModel> _entities = <int, TaskModel>{};

  Iterable<Filter> get groupKeys => _indexByGroup.keys;

  final Map<Filter, Map<int, int>> _indexByGroup = {};

  final Map<Filter, int?> _totalByGroup = {};
  
  // Отслеживание устаревших страниц (filter + pageIndex → isStale)
  final Map<String, bool> _pageStale = {};

  /// Вернуть срез из индекса + сущностей
  Future<List<TaskModel>> fetch({
    required Filter groupKey,
    required int offset,
    required int limit,
  }) async {
    final idx = _indexByGroup[groupKey] ?? const <int, int>{};
    final out = <TaskModel>[];
    for (var i = offset; i < offset + limit; i++) {
      final id = idx[i];
      if (id == null) break;
      final t = _entities[id];
      if (t == null) break;
      out.add(t);
    }
    return out;
  }

  Future<int> prefixEnd(Filter g) async {
    final idx = _indexByGroup[g] ?? const <int, int>{};
    var i = 0;
    while (idx.containsKey(i)) i++;
    return i;
  }

  /// Выставить total ТОЛЬКО если короткая страница пришла с фронтира префикса.
  Future<void> updateTotalFromPageIfFrontier({
    required Filter filter,
    required int pageOffset, // missingFrom
    required int requested, // fetchLimit
    required int received, // tasks.length
  }) async {
    final frontier = await prefixEnd(filter);
    if (pageOffset == frontier && received < requested) {
      await setTotal(filter, frontier + received);
    }
  }

  Future<void> setTotal(Filter g, int? total) async {
    _totalByGroup[g] = total; // total == null -> «конец неизвестен»
  }

  Future<int?> getTotal(Filter g) async => _totalByGroup[g];

  Future<void> clearTotal(Filter g) async => _totalByGroup.remove(g);

  /// Получить ключ страницы для staleness tracking
  String _pageKey(Filter filter, int pageIndex) {
    return '${filter.hashCode}_$pageIndex';
  }

  /// Получить pageIndex по offset и pageSize
  int _getPageIndex(int offset, int pageSize) {
    return offset ~/ pageSize;
  }

  /// Помечает все страницы группы как устаревшие (для refresh)
  Future<void> markAllPagesStale(Filter filter) async {
    final idx = _indexByGroup[filter] ?? const <int, int>{};
    final maxIndex = idx.keys.isEmpty ? 0 : idx.keys.reduce((a, b) => a > b ? a : b);
    final maxPageSize = 50; // разумное предположение о максимальном pageSize
    
    // Помечаем все возможные страницы как stale
    for (var pageIndex = 0; pageIndex <= (maxIndex ~/ 10) + 1; pageIndex++) {
      _pageStale[_pageKey(filter, pageIndex)] = true;
    }
  }

  /// Помечает страницу как свежую (после загрузки)
  Future<void> markPageFresh(Filter filter, int offset, int pageSize) async {
    final pageIndex = _getPageIndex(offset, pageSize);
    _pageStale[_pageKey(filter, pageIndex)] = false;
  }

  /// Проверяет устарела ли страница
  Future<bool> isPageStale(Filter filter, int offset, int pageSize) async {
    final pageIndex = _getPageIndex(offset, pageSize);
    return _pageStale[_pageKey(filter, pageIndex)] ?? false;
  }

  Future<void> upsertTasks({
    required Filter groupKey,
    required int from,
    required List<TaskModel> tasks,
    int pageSize = 10,
  }) async {
    final idx =
        Map<int, int>.from(_indexByGroup[groupKey] ?? const <int, int>{});
    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      idx[from + i] = t.id;
      _entities[t.id] = t;
    }
    _indexByGroup[groupKey] = idx;
    
    // Помечаем загруженную страницу как свежую
    await markPageFresh(groupKey, from, pageSize);
  }

  Future<void> deleteGroup(Filter groupKey) async {
    _indexByGroup.remove(groupKey);
  }

  Future<void> deleteEntity(int id) async {
    for (final gk in _indexByGroup.keys) {
      final idx = _indexByGroup[gk];
      if (idx == null || idx.isEmpty) continue;

      final positions = _findPositions(idx, id);
      if (positions.isEmpty) continue;

      var next = Map<int, int>.from(idx);
      // сортируем, чтобы сдвиги шли стабильно слева-направо
      for (final pos in positions..sort()) {
        next = _reindexAfterDelete(next, pos);
      }
      _indexByGroup[gk] = next;

      // >>> Любое структурное изменение делает прежний total недостоверным
      await clearTotal(gk);
    }
    await _purgeEntityIfOrphan(
        id); // (опционально) можно удалять id из entities, если он больше нигде не встречается.
  }

  Future<void> updateEntity(TaskModel task) async {
    _entities[task.id] = task;

    for (final gk in _indexByGroup.keys.toList()) {
      final idx = _indexByGroup[gk] ?? const <int, int>{};
      final has = idx.containsValue(task.id);
      final matches = gk.matches(task);
      final cmp = gk.orderBy;

      if (!matches) {
        // был в группе, но больше не подходит — удалить с реиндексом
        if (has) {
          var next = Map<int, int>.from(idx);
          for (final pos in _findPositions(idx, task.id)..sort()) {
            next = _reindexAfterDelete(next, pos);
          }
          _indexByGroup[gk] = next;
          await clearTotal(gk); // структура изменилась → конец неизвестен
        }
        continue;
      }

      final prefixLen = _prefixLen(idx);
      final currentPos = _firstPosition(idx, task.id); // -1 если нет в префиксе

      // Собираем «загруженный префикс» как список моделей
      final loaded = <TaskModel>[];
      for (var i = 0; i < prefixLen; i++) {
        final id = idx[i];
        if (id == null) break;
        final t = _entities[id];
        if (t == null) break;
        loaded.add(t);
      }

      if (cmp == null) {
        // порядок не определяем — не вставляем за край и не двигаем
        continue;
      }

      // База для расчёта желаемой позиции
      final base = List<TaskModel>.from(loaded);
      if (currentPos != -1) {
        // если элемент уже в префиксе, временно уберём его перед расчётом позиции
        base.removeAt(currentPos);
      }

      final desired = _lowerBound(base, task, cmp);

      // Правило: НЕ вставляем/не двигаем в конец префикса (desired == base.length)
      final intoTail = desired >= base.length;

      if (!has) {
        // элемента не было в группе
        if (!intoTail) {
          // вставляем внутрь префикса
          var next = Map<int, int>.from(idx);
          next = _insertAt(next, desired, task.id, prefixLen);
          _indexByGroup[gk] = next;
          await clearTotal(gk); // структура изменилась
        } else {
          // << ключевой случай: правильное место — СРАЗУ ПОСЛЕ префикса
          // мы НЕ вставляем сейчас, чтобы не ломать пагинацию,
          // а total делаем «неизвестным», т.к. возможно «дальше есть ещё»
          await clearTotal(gk);
        }
        // else: пропускаем вставку — пусть появится при следующей подкачке
      } else {
        // элемент уже есть в группе
        if (currentPos == -1) {
          // элемент за пределами префикса; корректное место — в «хвосте» префикса?
          if (intoTail) {
            await clearTotal(gk); // возможно есть дальше ещё элементы
          }
          // был за пределами префикса — не трогаем (чтобы не «вытягивать» внутрь)

          continue;
        }
        if (intoTail) {
          // Не двигаем в конец — остаётся на старом месте
          await clearTotal(gk);
          continue;
        }
        if (desired == currentPos) {
          // позиция не изменилась
          continue;
        }
        // Переставляем внутри префикса: удаляем + вставляем
        var next = Map<int, int>.from(idx);
        next = _reindexAfterDelete(next, currentPos);
        next = _insertAt(
            next, desired, task.id, /*prefixLen after delete*/ prefixLen - 1);
        _indexByGroup[gk] = next;
        await clearTotal(gk);
      }
    }
  }

  /// бинарный поиск места вставки (lowerBound) по компаратору
  int _lowerBound(
      List<TaskModel> list, TaskModel x, Comparator<TaskModel> cmp) {
    var lo = 0, hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (cmp(x, list[mid]) <= 0) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  /// Вставка внутрь «загруженного префикса» [0..prefixLen)
  Map<int, int> _insertAt(Map<int, int> index, int pos, int id, int prefixLen) {
    final next = Map<int, int>.from(index);
    // сдвигаем хвост [pos..prefixLen-1] вверх на 1
    for (var i = prefixLen - 1; i >= pos; i--) {
      final v = next[i];
      if (v == null) continue;
      next[i + 1] = v;
    }
    next[pos] = id;
    return next;
  }

  int _prefixLen(Map<int, int> idx) {
    var i = 0;
    while (idx.containsKey(i)) i++;
    return i;
  }

  List<int> _findPositions(Map<int, int> idx, int id) {
    final out = <int>[];
    idx.forEach((pos, pid) {
      if (pid == id) out.add(pos);
    });
    return out;
  }

  Future<void> _purgeEntityIfOrphan(int id) async {
    // если ни в одном индексе нет этого id — удалим из entities
    for (final idx in _indexByGroup.values) {
      if (idx.containsValue(id)) return; // ещё встречается — не удаляем
    }
    _entities.remove(id); // больше нигде не используется — чистим
  }

  int _firstPosition(Map<int, int> idx, int id) {
    var i = 0;
    while (idx.containsKey(i)) {
      if (idx[i] == id) return i;
      i++;
    }
    return -1;
  }

  Map<int, int> _reindexAfterDelete(Map<int, int> index, int removedPos) {
    final next = Map<int, int>.from(index)..remove(removedPos);
    var i = removedPos + 1;
    while (next.containsKey(i)) {
      next[i - 1] = next[i]!;
      next.remove(i);
      i++;
    }
    return next;
  }
}
