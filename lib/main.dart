import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

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
      home: Row(
        children: [
          Expanded(
            child: const MyHomePage(
              title: 'Flutter Demo Home Page',
              limit: 15,
              filter: '1',
            ),
          ),
          const VerticalDivider(),
          Expanded(
            child: const MyHomePage(
              title: 'Flutter Demo Home Page',
              limit: 20,
              filter: '2',
            ),
          ),
        ],
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage(
      {super.key,
      required this.title,
      required this.limit,
      required this.filter});

  final String title;
  final int limit;
  final String filter;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _repository = RepositorySample.instance;

  bool _isLoading = false;

  int _offset = 0;
  late final int _limit;

  final _subscriptions = CompositeSubscription();

  final Map<int, List<ItemModel>> _pagesMap = {};

  @override
  void initState() {
    _limit = widget.limit;
    _loadItems(force: true);
    super.initState();
  }

  void _loadItems({bool force = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final currentOffset = _offset;

    final stream = await _repository
        .getItemsStream(currentOffset, _limit, widget.filter, force: force);
    _offset += _limit;

    _subscriptions.add(stream.listen((items) {
      setState(() {
        _pagesMap[currentOffset] = items;
      });
    }));

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _pagesMap.clear();
      _offset = 0;
    });

    await _subscriptions.clear();

    _loadItems(force: true);
  }

  List<ItemModel>? get _items => _pagesMap.values.expand((e) => e).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
          'Items: ${(_items?.length).toString()} | Offset: $_offset | Limit: $_limit',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      body: Stack(
        children: [
          ListView.builder(
            itemCount: _items?.length ?? 0,
            itemBuilder: (context, index) {
              final item = _items![index];
              return ListTile(
                dense: true,
                title: Text(item.name),
                trailing: IconButton(
                  onPressed: () {
                    _repository.likeItem(item.id, !(item.isLiked));
                  },
                  icon: Icon(
                      item.isLiked ? Icons.favorite : Icons.favorite_border),
                ),
              );
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: _refresh,
            tooltip: 'Increment',
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _loadItems,
            tooltip: 'Increment',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () {
              print(_repository._entries);
            },
            tooltip: 'Get info',
            child: const Icon(Icons.info),
          ),
        ],
      ),
    );
  }
}

class _Entry<T> {
  final BehaviorSubject<T> subject = BehaviorSubject<T>();

  DateTime? updatedAt;

  Future<void>? inFlight;

  bool get hasData => subject.hasValue;
}

class RepositorySample {
  RepositorySample._();

  static final RepositorySample _instance = RepositorySample._();

  static RepositorySample get instance => _instance;

  final Map<String, _Entry<List<ItemModel>>> _entries = {};

  String _getEntryKey(int offset, int limit, String filter) {
    return '$offset-$limit-$filter';
  }

  Future<Stream<List<ItemModel>>> getItemsStream(
    int offset,
    int limit,
    String filter, {
    bool force = false,
  }) async {
    assert(offset >= 0 && limit > 0, 'offset >= 0, limit > 0');

    final key = _getEntryKey(offset, limit, filter);

    final e = (_entries[key] ??= _Entry<List<ItemModel>>());

    if (force || !e.hasData) {
      await _fetchInto(e, () => _getItems(offset, limit, filter));
    }

    return e.subject.stream;
  }

  Future<void> likeItem(int id, bool isLiked) async {
    _entries.forEach((key, entry) {
      final items = List.of(entry.subject.valueOrNull ?? <ItemModel>[]);
      if (items.isNotEmpty) {
        final item = items.indexWhere((e) => e.id == id);
        if (item != -1) {
          items[item] = items[item].copyWith(isLiked: isLiked);
        }
        entry.subject.add(items);
      }
    });
  }

  

  Future<void> _fetchInto(_Entry<List<ItemModel>> e,
      Future<List<ItemModel>> Function() fetcher) async {
    if (e.inFlight != null) return;

    e.inFlight = fetcher().then((value) {
      e.subject.add(value);
      e.updatedAt = DateTime.now();
    }).whenComplete(() => e.inFlight = null);

    await e.inFlight;
  }

  Future<List<ItemModel>> _getItems(
      int offset, int limit, String filter) async {
    print('Load items: $offset, $limit, $filter');
    await Future.delayed(const Duration(seconds: 2));
    return List.generate(
      limit,
      (index) {
        final id = offset + index;
        return ItemModel(
          id: id,
          name: 'Item $id',
          isLiked: false,
        );
      },
    );
  }
}

class ItemModel {
  final int id;
  final String name;
  final bool isLiked;

  ItemModel({
    required this.id,
    required this.name,
    required this.isLiked,
  });

  ItemModel copyWith({bool? isLiked}) {
    return ItemModel(
      id: id,
      name: name,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
