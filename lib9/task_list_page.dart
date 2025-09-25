import 'package:flutter/material.dart';

import 'filter_model.dart';
import 'main.dart';
import 'task_list_bloc.dart';
import 'task_list_data.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key, required this.filter});

  final Filter filter;

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  late final bloc = TaskListBloc(filter: widget.filter);
  late final ScrollController controller = ScrollController();

  @override
  void initState() {
    bloc.init();
    controller.addListener(() {
      if (controller.position.pixels == controller.position.maxScrollExtent) {
        // bloc.loadMore();
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TaskListState>(
        stream: bloc.state$,
        builder: (context, snapshot) {
          final state = snapshot.data;

          if (state == null) return const SizedBox.shrink();

          return Scaffold(
            appBar: AppBar(
              title: Text(
                '${widget.filter.runtimeType} | length: ${state.tasks.length} | hasMore: ${state.hasMore}',
                style: TextStyle(fontSize: 14),
              ),
            ),
            floatingActionButton: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  mini: true,
                  onPressed: () {
                    bloc.refresh();
                  },
                  child: const Icon(Icons.refresh),
                ),
                SizedBox(
                  height: 10,
                ),
                FloatingActionButton(
                  mini: true,
                  onPressed: () {
                    bloc.loadMore();
                  },
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            body: Stack(
              children: [
                ListView.builder(
                  controller: controller,
                  itemCount: state.tasks.length,
                  itemBuilder: (context, index) {
                    final task = state.tasks[index];
                    return Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            bloc.delete(task);
                          },
                          icon: Icon(Icons.delete),
                        ),
                        Checkbox(
                          value: task.isCompleted,
                          onChanged: (value) {
                            bloc.setCompleted(task.id, value!);
                          },
                        ),
                        Text(
                          task.title,
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pushNamed(context, Routes.taskDetail, arguments: task.id);
                          },
                          icon: Icon(Icons.forward),
                        ),
                      ],
                    );
                  },
                ),
                if (state.isLoading)
                  Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          );
        });
  }
}
