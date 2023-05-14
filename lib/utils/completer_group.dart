import 'dart:async';

class CompleterGroup<T, R> {
  late final Map<T, Completer<R>> _registeredCompleters = {};

  void register(T key) {
    _registeredCompleters[key] = Completer<R>();
  }

  void complete(T key, [R? value]) {
    _registeredCompleters[key]?.complete(value);
  }

  Future<void> waitForSingle(T key) {
    final completer = _registeredCompleters[key];

    if (completer == null) {
      throw Exception("Completer with key $key is not present in aggregator");
    }

    return completer.future;
  }

  Future<List<R>> waitForCompletion([List<T>? filter]) {
    final Iterable<Completer<R>> completers =
        filter != null && filter.isNotEmpty
            ? _registeredCompleters.entries
                .where((e) => filter.contains(e.key))
                .map((e) => e.value)
            : _registeredCompleters.values;

    return Future.wait<R>(completers.map((e) => e.future));
  }
}
