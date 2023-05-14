import 'dart:async';

import 'package:dahlia_shared/utils/completer_group.dart';
import 'package:flutter/foundation.dart';
import 'package:dahlia_shared/utils/log.dart';

abstract class Service<T extends Service<T>> with LoggerProvider {
  bool _running = false;
  bool get running => _running;

  FutureOr<void> start();
  FutureOr<void> stop();

  @override
  String toString() {
    return "$T, ${running ? "running" : "not running"}";
  }
}

abstract class ListenableService<T extends ListenableService<T>>
    extends Service<T> with ChangeNotifier {}

class FailedService extends Service<FailedService> {
  final Type service;

  FailedService._(this.service);

  @override
  FutureOr<void> start() => _error();

  @override
  FutureOr<void> stop() => _error();

  Never _error() {
    throw UnimplementedError(
      "Instances of FailedService exist only to signal that a service that was supposed to exist does not for some reason. Avoid calling any method on such instances.",
    );
  }

  @override
  String toString() {
    return "$service, failed";
  }
}

typedef ServiceBuilder<T extends Service<T>> = FutureOr<T> Function();

class ServiceManager with LoggerProvider {
  final Map<Type, _ServiceBuilderWithFallback> _awaitingForStartup = {};
  final CompleterGroup<Type> _completers = CompleterGroup();
  final Map<Type, Service<dynamic>> _registeredServices = {};
  final List<Type> _criticalServices = [];
  static final ServiceManager _instance = ServiceManager._();

  ServiceManager._();

  static void registerService<T extends Service<T>>(
    ServiceBuilder<T> builder, {
    T? fallback,
    bool critical = false,
  }) =>
      _instance._registerService<T>(
        builder,
        fallback: fallback,
        critical: critical,
      );

  static Future<void> startServices() => _instance._startServices();

  static Future<void> stopServices() => _instance._stopServices();

  static Future<void> waitForService<T extends Service<T>>() =>
      _instance._waitForService<T>();

  static Future<void> unregisterService<T extends Service<T>>() =>
      _instance._unregisterService<T>();

  static T? getService<T extends Service<T>>() => _instance._getService<T>();

  void _registerService<T extends Service<T>>(
    ServiceBuilder<T> builder, {
    T? fallback,
    bool critical = false,
  }) {
    _awaitingForStartup[T] = (builder, fallback);
    _completers.register(T);

    if (critical) _criticalServices.add(T);
  }

  Future<void> _waitForService<T extends Service<T>>() {
    try {
      return _completers.waitForSingle(T);
    } catch (e) {
      throw Exception(
        "Can't wait for Service $T because it was not registered",
      );
    }
  }

  Future<void> _startServices() async {
    for (final MapEntry(:key, :value) in _awaitingForStartup.entries) {
      _startService(key, value);
    }

    return _completers.waitForCompletion(_criticalServices);
  }

  Future<void> _startService(
    Type type,
    _ServiceBuilderWithFallback builderFn,
  ) async {
    logger.info("Starting service $type");

    final (builder, fallback) = builderFn;
    final Service<dynamic> service =
        await _startWithFallback(type, builder, fallback);

    logger.info("Started service $type");
    _registeredServices[type] = service;
    _completers.complete(type);
  }

  Future<void> _stopServices() async {
    for (final Type type in _registeredServices.keys) {
      await _unregisterServiceByType(type);
    }

    // Better safe than sorry
    _registeredServices.clear();
  }

  Future<Service<dynamic>> _startWithFallback(
    Type type,
    ServiceBuilder<Service<dynamic>> builder,
    Service<dynamic>? fallback,
  ) async {
    try {
      final Service<dynamic> service = await builder();
      await service.start();
      service._running = true;

      return service;
    } catch (exception, stackTrace) {
      if (fallback == null) {
        logger.severe(
          "The service $type failed to start",
          exception,
          stackTrace,
        );

        return FailedService._(type);
      }

      logger.warning(
        "The service $type failed to start",
        exception,
        stackTrace,
      );
      logger.info("Starting fallback service for $type");

      return _startWithFallback(type, () => fallback, null);
    }
  }

  Future<void> _unregisterService<T extends Service<T>>() =>
      _unregisterServiceByType(T);

  Future<void> _unregisterServiceByType(Type type) async {
    final Service<dynamic>? service = _registeredServices.remove(type);
    await service?.stop();
    service?._running = false;
  }

  T? _getService<T extends Service<T>>() {
    final Service<dynamic>? service = _registeredServices[T];

    if (service == null) return null;

    if (!service.running || service is FailedService) {
      throw ServiceNotRunningException<T>();
    }

    return service as T;
  }
}

class ServiceNotRunningException<T extends Service<T>> implements Exception {
  const ServiceNotRunningException();

  @override
  String toString() {
    return 'The service $T is currently not running.\n'
        'This is probably caused by an exception thrown while starting, consider adding a fallback service to avoid these situations.';
  }
}

typedef _ServiceBuilderWithFallback<T extends Service<T>> = (
  ServiceBuilder<T>,
  T? fallback
);
