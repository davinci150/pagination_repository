import 'task_model.dart';

sealed class Filter {
  Filter({required this.type});

  final int type;

  bool matches(TaskModel t);

  Comparator<TaskModel> get orderBy;

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;
}

final class CompletedFilter extends Filter {
  CompletedFilter() : super(type: 1);

  @override
  bool matches(TaskModel task) => task.isCompleted;

  @override
  Comparator<TaskModel> get orderBy => (a, b) => a.title.compareTo(b.title);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompletedFilter &&
          runtimeType == other.runtimeType &&
          type == other.type;

  @override
  int get hashCode => type.hashCode;

  @override
  String toString() => 'CompletedFilter';
}

final class NotCompletedFilter extends Filter {
  NotCompletedFilter() : super(type: 2);

  @override
  bool matches(TaskModel task) => !task.isCompleted;

  @override
  Comparator<TaskModel> get orderBy => (a, b) => a.title.compareTo(b.title);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotCompletedFilter &&
          runtimeType == other.runtimeType &&
          type == other.type;

  @override
  int get hashCode => type.hashCode;

  @override
  String toString() => 'NotCompletedFilter';
}
