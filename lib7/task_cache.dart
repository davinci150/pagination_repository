import 'filter_model.dart';
import 'task_model.dart';

class TasksCache {
  final Map<int, TaskModel> _entities = <int, TaskModel>{};

  Iterable<Filter> get groupKeys => _indexByGroup.keys;

  final Map<Filter, Map<int, int>> _indexByGroup = {};

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

  Future<void> upsertTasks({
    required Filter groupKey,
    required int from,
    required List<TaskModel> tasks,
  }) async {
    final idx =
        Map<int, int>.from(_indexByGroup[groupKey] ?? const <int, int>{});
    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      idx[from + i] = t.id;
      _entities[t.id] = t;
    }
    _indexByGroup[groupKey] = idx;
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
    }
    await _purgeEntityIfOrphan(
        id); // (опционально) можно удалять id из entities, если он больше нигде не встречается.
  }

  Future<void> updateEntity(TaskModel task) async {
    _entities[task.id] = task;
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
