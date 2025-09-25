class TaskDetailsModel {
  TaskDetailsModel({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.description,
  });

  final int id;
  final String title;
  final bool isCompleted;
  final String description;

  TaskDetailsModel copyWith({
    int? id,
    String? title,
    bool? isCompleted,
    String? description,
  }) {
    return TaskDetailsModel(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      description: description ?? this.description,
    );
  }
}
