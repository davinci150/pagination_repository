import 'filter_model.dart';
import 'task_list_bloc.dart';

/// Тест для проверки работы multiple subscribers с одним фильтром
void testMultipleSubscribers() async {
  print('=== Testing Multiple Subscribers ===');
  
  final filter = Filter(type: 0);
  
  // Два блока с одним фильтром
  final bloc1 = TaskListBloc(filter: filter);
  final bloc2 = TaskListBloc(filter: filter);
  
  // Инициализируем оба блока
  await bloc1.init();
  await bloc2.init();
  
  print('\n--- Initial state ---');
  
  // Подписываемся на данные
  bloc1.tasks$.listen((data) {
    print('BLOC1: ${data.tasks.length} tasks, total: ${data.total}');
  });
  
  bloc2.tasks$.listen((data) {
    print('BLOC2: ${data.tasks.length} tasks, total: ${data.total}');
  });
  
  await Future.delayed(Duration(seconds: 2));
  
  print('\n--- BLOC1 loads more ---');
  await bloc1.loadMore(); // Bloc1 загружает больше данных
  
  await Future.delayed(Duration(seconds: 2));
  
  print('\n--- BLOC2 refresh ---');
  await bloc2.refresh(); // Bloc2 делает refresh
  
  await Future.delayed(Duration(seconds: 2));
  
  print('\n--- BLOC1 loads more again ---');
  await bloc1.loadMore(); // Bloc1 загружает ещё больше
  
  await Future.delayed(Duration(seconds: 2));
  
  print('\n=== Test completed ===');
}

/// Демонстрация ожидаемого поведения
void printExpectedBehavior() {
  print('=== Expected Behavior ===');
  print('1. Both blocs start with 10 items');
  print('2. BLOC1 loadMore() → BLOC1 gets 20 items, BLOC2 stays 10 items');
  print('3. BLOC2 refresh() → BLOC2 refreshes all pages, both blocs get fresh data');
  print('4. BLOC1 loadMore() → BLOC1 gets 30 items (fresh), BLOC2 stays at refreshed size');
  print('');
}

void main() async {
  printExpectedBehavior();
  await testMultipleSubscribers();
}