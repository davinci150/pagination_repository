import 'package:flutter/material.dart';

import 'filter_model.dart';
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
        bloc.loadMore();
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TaskListData>(
        stream: bloc.tasks$,
        builder: (context, snapshot) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                '${widget.filter.runtimeType} | length: ${snapshot.data?.tasks.length}',
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
                  itemCount: snapshot.data?.tasks.length ?? 0,
                  itemBuilder: (context, index) {
                    final task = snapshot.data!.tasks[index];
                    return Row(
                      children: [
                        Checkbox(
                          value: task.isCompleted,
                          onChanged: (value) {
                            bloc.setCompleted(task.id, value ?? false);
                          },
                        ),
                        Text(
                          task.title,
                        ),
                      ],
                    );
                  },
                ),
                StreamBuilder<bool>(
                  stream: bloc.progress$,
                  builder: (context, snapshot) {
                    if (snapshot.data == true) {
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    return SizedBox.shrink();
                  },
                ),
              ],
            ),
          );
        });
  }
}
