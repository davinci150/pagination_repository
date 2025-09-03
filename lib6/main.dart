import 'package:flutter/material.dart';

import 'filter_model.dart';
import 'task_list_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Column(
        children: [
          Expanded(
            child: TaskListPage(
              filter: NotCompletedFilter(),
            ),
          ),
          Divider(),
          Expanded(
            child: TaskListPage(
              //filter: CompletedFilter(),
              filter: NotCompletedFilter(),
            ),
          ),
        ],
      ),
    );
  }
}
