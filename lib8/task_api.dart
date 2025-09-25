import 'dart:math';

import 'filter_model.dart';
import 'task_details_model.dart';
import 'task_model.dart';

class TaskApi {
  TaskApi._() {
    data = List.generate(
      _maxItems,
      (index) {
        final num = (index + 1).toString().padLeft(2, '0');
        return TaskModel(
          id: index + 1,
          title: 'Task $num',
          isCompleted: Random().nextBool(),
        );
      },
    );
  }

  static final TaskApi _instance = TaskApi._();

  static TaskApi get instance => _instance;

  final Duration _delay = const Duration(milliseconds: 1000);

  final int _maxItems = 120;

  late final List<TaskModel> data;

  Future<TaskDetailsModel> getTask(int id) async {
    await Future.delayed(_delay);
    final task = data.firstWhere((e) => e.id == id);
    return TaskDetailsModel(
      id: task.id,
      title: task.title,
      isCompleted: task.isCompleted,
      description: 'Description for task ${task.id}',
    );
  }

  Future<List<TaskModel>> getTasks({
    required Filter filter,
    required int offset,
    required int limit,
  }) async {
    print(
        '[TaskApi] getTasks ${filter.runtimeType} from $offset to ${offset + limit}');
    await Future.delayed(_delay);
    final result = data.where((e) {
      if (filter.type == 2) {
        return !e.isCompleted;
      } else if (filter.type == 1) {
        return e.isCompleted;
      }
      return false;
    }).toList();

    if (offset >= result.length) {
      return [];
    }

    return result.sublist(
        offset, result.length > offset + limit ? offset + limit : null);
  }

/*   Future<void> update(TaskModel model) async {
    print('[TaskApi] update ${model.id}');
    await Future.delayed(_delay);
    final index = data.indexWhere((element) => element.id == model.id);
    if (index != -1) {
      data[index] = model;
    }
  } */

  Future<void> setCompleted(
      {required bool isCompleted, required int id}) async {
    print('[TaskApi] setCompleted $isCompleted $id');
    await Future.delayed(_delay);
    final index = data.indexWhere((element) => element.id == id);
    if (index != -1) {
      data[index] = data[index].copyWith(isCompleted: isCompleted);
    }
  }

  Future<void> create(TaskModel model) async {
    print('[TaskApi] create ${model.id}');
    await Future.delayed(_delay);

    data.add(model);
  }

  Future<void> delete(TaskModel model) async {
    print('[TaskApi] delete ${model.id}');
    await Future.delayed(_delay);
    final index = data.indexWhere((element) => element.id == model.id);
    if (index != -1) {
      data.removeAt(index);
    }
  }
}
