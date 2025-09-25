import 'task_api.dart';
import 'task_details_repository.dart';
import 'task_repository.dart';

class TaskService {
  final _api = TaskApi.instance;
  final _repo = TaskRepository.instance;
  final _detailsRepo = TaskDetailsRepository.instance;

  Future<void> setCompleted(int id, bool isCompleted) async {
    await _api.setCompleted(isCompleted: isCompleted, id: id);

    final model = await _repo.getById(id, onlyCache: true);
    if (model != null) {
      final updated = model.copyWith(isCompleted: isCompleted);
      await _repo.update(updated);
    }

    final detailsModel = await _detailsRepo.getTaskDetails(id, onlyCache: true);
    if (detailsModel != null) {
      final updated = detailsModel.copyWith(isCompleted: isCompleted);
      await _detailsRepo.updateTaskDetails(updated);
    }
  }
}
