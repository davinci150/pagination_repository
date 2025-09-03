import 'task_model.dart';

class TaskListData {
  TaskListData({
    required this.tasks,
    required this.total,
  });

  final List<TaskModel> tasks;
  final int? total;
}
