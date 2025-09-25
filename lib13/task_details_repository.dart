import 'package:rxdart/rxdart.dart';

import 'task_api.dart';
import 'task_details_model.dart';

class TaskDetailsRepository {
  TaskDetailsRepository._();

  static final TaskDetailsRepository _instance = TaskDetailsRepository._();

  static TaskDetailsRepository get instance => _instance;

  final _api = TaskApi.instance;

  final Map<int, BehaviorSubject<TaskDetailsModel>> _taskDetailsStreams = {};

  Future<Stream<TaskDetailsModel>> getTaskDetailsStream(int taskId) async {
    if (!_taskDetailsStreams.containsKey(taskId)) {
      final task = await _api.getTask(taskId);
      _taskDetailsStreams.putIfAbsent(
        taskId,
        () => BehaviorSubject<TaskDetailsModel>.seeded(
          task,
          onCancel: () {
            _taskDetailsStreams[taskId]!.close();
            _taskDetailsStreams.remove(taskId);
          },
        ),
      );
    }
    return _taskDetailsStreams[taskId]!.stream;
  }

  Future<TaskDetailsModel?> getTaskDetails(int id,
      {bool onlyCache = false}) async {
    return await _api.getTask(id);
  }

  Future<void> updateTaskDetails(TaskDetailsModel model) async {
    //await _api.updateTaskDetails(model);
  }
}
