class TaskModel {
  TaskModel({
    required this.id,
    required this.title,
    required this.isCompleted,
  });

  final int id;
  final String title;
  final bool isCompleted;

  TaskModel copyWith({
    int? id,
    String? title,
    bool? isCompleted,
  }) {
    return TaskModel(id: id ?? this.id, title: title ?? this.title, isCompleted: isCompleted ?? this.isCompleted);
  }
}
