import 'dart:async';

class CompleterGroup<T> {
  late final Map<T, Completer<void>> _registeredCompleters = {};

  void register(T key) {
    _registeredCompleters[key] = Completer<void>();
  }

  void complete(T key) {
    _registeredCompleters[key]?.complete();
  }

  Future<void> waitForSingle(T key) {
    final completer = _registeredCompleters[key];

    if (completer == null) {
      throw Exception("Completer with key $key is not present in aggregator");
    }

    return completer.future;
  }

  Future<void> waitForCompletion([List<T>? filter]) {
    final Iterable<Completer<void>> completers =
        filter != null && filter.isNotEmpty
            ? _registeredCompleters.entries
                .where((e) => filter.contains(e.key))
                .map((e) => e.value)
            : _registeredCompleters.values;

    return Future.wait<void>(completers.map((e) => e.future));
  }
}
