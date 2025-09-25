import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import 'model/filter_model.dart';
import 'task_detail/task_details_page.dart';
import 'task_list/task_list_page.dart';

void main() {
  runApp(const MyApp());
}

PublishSubject<bool> invalidateCache$ = PublishSubject<bool>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData.dark(
        useMaterial3: true,
      ),
      home: Column(
        children: [
          TextButton(
            onPressed: () {
              invalidateCache$.add(true);
            },
            child: const Text('Invalidate Cache'),
          ),
          Expanded(
            child: Navigator(
              initialRoute: Routes.taskList,
              onGenerateRoute: (settings) {
                if (settings.name == Routes.taskList) {
                  return MaterialPageRoute(
                    builder: (context) => TaskListPage(
                      filter: NotCompletedFilter(),
                    ),
                  );
                } else if (settings.name == Routes.taskDetail) {
                  return MaterialPageRoute(
                    builder: (context) => TaskDetailsPage(
                      id: settings.arguments as int,
                    ),
                  );
                }
                return MaterialPageRoute(
                  builder: (context) => Container(
                    color: Colors.red,
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: Navigator(
              initialRoute: Routes.taskList,
              onGenerateRoute: (settings) {
                if (settings.name == Routes.taskList) {
                  return MaterialPageRoute(
                    builder: (context) => TaskListPage(
                      filter: NotCompletedFilter(),
                    ),
                  );
                } else if (settings.name == Routes.taskDetail) {
                  return MaterialPageRoute(
                    builder: (context) => TaskDetailsPage(
                      id: settings.arguments as int,
                    ),
                  );
                }
                return MaterialPageRoute(
                  builder: (context) => Container(
                    color: Colors.red,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class Routes {
  static const String taskList = '/task-list';
  static const String taskDetail = '/task-detail';
}
