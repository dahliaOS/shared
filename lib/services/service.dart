import 'dart:async';

import 'package:dahlia_shared/utils/completer_group.dart';
import 'package:flutter/foundation.dart';
import 'package:dahlia_shared/utils/log.dart';

abstract class Service with LoggerProvider {
  bool _running = false;
  bool get running => _running;

  void setRunning() {
    if (_running) throw Exception("Service is already running");
    _running = true;
  }

  FutureOr<void> start();
  FutureOr<void> stop();

  @override
  String toString() {
    return "$runtimeType, ${running ? "running" : "not running"}";
  }
}

abstract class ListenableService extends Service with ChangeNotifier {}

class FailedService extends Service {
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

typedef ServiceBuilder<T extends Service> = T Function();
typedef FallbackServiceBuilder<T extends Service> = T? Function();

abstract class ServiceFactory<T extends Service> {
  const ServiceFactory();

  T build();
  T? fallback() => null;
}

class ServiceManager with LoggerProvider {
  final Map<Type, ServiceFactory<Service>> _awaitingForStartup = {};
  final CompleterGroup<Type, void> _completers = CompleterGroup();
  final Map<Type, Service> _registeredServices = {};
  final List<Type> _criticalServices = [];
  static final ServiceManager _instance = ServiceManager._();

  ServiceManager._();

  static void registerService<T extends Service>(
    ServiceFactory<T> factory, {
    bool critical = false,
  }) =>
      _instance._registerService(factory, critical: critical);

  static Future<void> startServices() => _instance._startServices();

  static Future<void> stopServices() => _instance._stopServices();

  static Future<void> waitForService<T extends Service>() =>
      _instance._waitForService<T>();

  static Future<void> unregisterService<T extends Service>() =>
      _instance._unregisterService<T>();

  static T? getService<T extends Service>() => _instance._getService();

  void _registerService<T extends Service>(
    ServiceFactory<T> factory, {
    bool critical = false,
  }) {
    _awaitingForStartup[T] = factory;
    _completers.register(T);

    if (critical) _criticalServices.add(T);
  }

  Future<void> _waitForService<T extends Service>() {
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

    await _completers.waitForCompletion(_criticalServices);
  }

  Future<void> _startService(
    Type type,
    ServiceFactory factory,
  ) async {
    logger.info("Starting service $type");

    final Service service =
        await _startWithFallback(type, factory.build, factory.fallback);

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

  Future<Service> _startWithFallback(
    Type type,
    ServiceBuilder<Service> builder,
    FallbackServiceBuilder<Service>? fallback,
  ) async {
    try {
      final Service service = builder();
      await service.start();
      service.setRunning();

      return service;
    } catch (exception, stackTrace) {
      final f = fallback?.call();
      if (f == null) {
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

      return _startWithFallback(type, () => f, null);
    }
  }

  Future<void> _unregisterService<T extends Service>() =>
      _unregisterServiceByType(T);

  Future<void> _unregisterServiceByType(Type type) async {
    final Service? service = _registeredServices.remove(type);
    await service?.stop();
    service?._running = false;
  }

  T? _getService<T extends Service>() {
    final Service? service = _registeredServices[T];

    if (service == null) return null;

    if (!service.running || service is FailedService) {
      throw ServiceNotRunningException<T>();
    }

    return service as T;
  }
}

class ServiceNotRunningException<T extends Service> implements Exception {
  const ServiceNotRunningException();

  @override
  String toString() {
    return 'The service $T is currently not running.\n'
        'This is probably caused by an exception thrown while starting, consider adding a fallback service to avoid these situations.';
  }
}
