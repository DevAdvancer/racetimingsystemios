import 'dart:async';

class DatabaseChangeNotifier {
  final StreamController<int> _controller = StreamController<int>.broadcast();
  int _version = 0;

  int get version => _version;

  Stream<int> get changes async* {
    yield _version;
    yield* _controller.stream;
  }

  void notifyChanged() {
    _version += 1;
    if (!_controller.isClosed) {
      _controller.add(_version);
    }
  }

  void dispose() {
    _controller.close();
  }
}
