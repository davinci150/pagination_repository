import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../model/task_details_model.dart';
import '../task_repository.dart';

class TaskDetailsBloc {
  TaskDetailsBloc({required this.id}) {
    _init();
  }

  final int id;

  final _state$ = BehaviorSubject<TaskDetailsState>.seeded(TaskDetailsState());

  Stream<TaskDetailsState> get state$ => _state$.stream;

  TaskDetailsState get state => _state$.value;

  final _repo = TaskRepository.instance;

  StreamSubscription? _taskDetailsSubscription;

  Future<void> _init() async {
    _state$.add(state.copyWith(isLoading: true));

    final taskDetailsStream = await _repo.getTaskDetailsStream(id);

    _state$.add(state.copyWith(isLoading: false));

    _taskDetailsSubscription = taskDetailsStream.listen((taskDetails) {
      _state$.add(state.copyWith(task: taskDetails));
    });
  }

  Future<void> setCompleted(bool isCompleted) async {
    _state$.add(state.copyWith(isLoading: true));
    await _repo.setCompleted(state.task?.id ?? 0, isCompleted);
    _state$.add(state.copyWith(isLoading: false));
  }

  void dispose() {
    _taskDetailsSubscription?.cancel();
    _state$.close();
  }
}

class TaskDetailsState {
  TaskDetailsState({this.task, this.isLoading = false});

  final TaskDetailsModel? task;
  final bool isLoading;

  TaskDetailsState copyWith({
    TaskDetailsModel? task,
    bool? isLoading,
  }) {
    return TaskDetailsState(
      task: task ?? this.task,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
