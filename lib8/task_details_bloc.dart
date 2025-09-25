import 'package:rxdart/rxdart.dart';

import 'task_details_model.dart';
import 'task_repository.dart';

class TaskDetailsBloc {
  TaskDetailsBloc({required this.id}) {
    init();
  }

  final int id;

  final _state$ = BehaviorSubject<TaskDetailsState>.seeded(TaskDetailsState());

  Stream<TaskDetailsState> get state$ => _state$.stream;

  TaskDetailsState get state => _state$.value;

  final _repo = TaskRepository.instance;

  Future<void> init() async {
    _state$.add(state.copyWith(isLoading: true));
    final task = await _repo.fetchById(id);
    _state$.add(state.copyWith(task: task, isLoading: false));
  }

  Future<void> setCompleted(bool isCompleted) async {
    _state$.add(state.copyWith(isLoading: true));
    await _repo.update(
      UpdateTaskCompleted(id: state.task?.id ?? 0, isCompleted: isCompleted),
    );
    _state$.add(state.copyWith(isLoading: false));
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
