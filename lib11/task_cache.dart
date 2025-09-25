import 'dart:async';

import 'filter_model.dart';
import 'task_model.dart';

class TasksCache {
  final Map<int, TaskModel> _entities = <int, TaskModel>{};

  final Map<Filter, Map<int, int>> _indexByGroup = {};

  Iterable<Filter> get groupKeys => _indexByGroup.keys;

  final StreamController<void> _updates = StreamController.broadcast();

  Stream<List<TaskModel>> getTasksStream(
    Filter groupKey, {
    required int offset,
    required int limit,
  }) async* {
    yield await fetch(groupKey: groupKey, offset: offset, limit: limit);

    yield* _updates.stream.asyncMap((_) {
      return fetch(groupKey: groupKey, offset: offset, limit: limit);
    });
  }

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

  Future<void> addAll({
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
    _updates.add(null);
  }

  Future<void> clear() async {
    _indexByGroup.clear();
    _entities.clear();
    _updates.add(null);
  }

  Future<void> delete(int id) async {
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

    _updates.add(null);
  }

  Future<void> update(TaskModel task) async {
    _entities[task.id] = task;
    _updates.add(null);
  }

  Future<TaskModel?> getById(int id) async {
    return _entities[id];
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

  Future<void> applyPatch(TaskPatch patch) async {
    final model = _entities[patch.id];
    if (model == null) return;
    final updated = model.copyWith(
      isCompleted: patch.isCompleted ?? model.isCompleted,
    );
    await update(updated);
  }
}

class TaskPatch {
  TaskPatch({
    required this.id,
    this.isCompleted,
  });

  final int id;
  final bool? isCompleted;
}
