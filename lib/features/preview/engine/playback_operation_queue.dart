/// Native players cannot cancel an in-flight seek. Serialize operations so
/// its completion cannot land after the latest request has been presented.
class PlaybackOperationQueue {
  Future<void> _tail = Future<void>.value();
  int _pending = 0;
  bool get hasPending => _pending > 0;

  Future<T?> run<T>(
      {required bool Function() isCurrent,
      required Future<T> Function() operation}) {
    _pending++;
    final result = _tail.then<T?>((_) async {
      if (!isCurrent()) return null;
      return operation();
    }).whenComplete(() => _pending--);
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}
