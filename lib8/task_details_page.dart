import 'package:flutter/material.dart';

import 'task_details_bloc.dart';

class TaskDetailsPage extends StatefulWidget {
  const TaskDetailsPage({super.key, required this.id});

  final int id;

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  late final bloc = TaskDetailsBloc(id: widget.id);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TaskDetailsState>(
        stream: bloc.state$,
        builder: (context, snapshot) {
          final state = snapshot.data;

          if (state == null) return const SizedBox.shrink();

          return Scaffold(
            appBar: AppBar(
              title: Text('Task Details'),
            ),
            body: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: state.task?.isCompleted ?? false,
                            onChanged: (value) {
                              bloc.setCompleted(value!);
                            },
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Text(
                            state.task?.isCompleted == true
                                ? 'Completed'
                                : 'Not Completed',
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Text(
                        state.task?.title ?? '',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Text(
                        state.task?.description ?? '',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
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
