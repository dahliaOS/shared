import 'dart:async';
import 'dart:convert';

import 'package:dahlia_shared/dahlia_shared.dart';
import 'package:dbus/dbus.dart';
import 'package:nm/nm.dart';

abstract class NetworkManagerService extends Service<NetworkManagerService> {
  NetworkManagerService();

  static NetworkManagerService get current => ServiceManager.getService<NetworkManagerService>()!;

  static NetworkManagerService build() => _NetworkManagerImpl();
  static NetworkManagerService fallback() => _NetworkManagerDummy();

  /// Start a scan for wifi access points
  Future<void> startWifiScan();

  /// Get a list of wifi access points
  List<AccessPoint> getWifiAccessPoints();

  /// Check if there is a wireless device
  bool get hasWirelessDevice;

  /// Check if wifi is enabled
  bool get isWifiEnabled;

  /// Turn off wifi
  Future<void> turnOffWifi();

  /// Turn on wifi
  Future<void> turnOnWifi();

  /// Toggle wifi status
  Future<void> toggleWifi();

  /// Check if wifi is connected
  bool get isWifiConnected;

  /// Check if wired is connected
  bool get isWiredConnected;
}

class _NetworkManagerImpl extends NetworkManagerService {
  final NetworkManagerClient _client = NetworkManagerClient();

  @override
  Future<void> start() async {
    await _client.connect();
  }

  @override
  void stop() {
    _client.close();
  }

  @override
  Future<void> startWifiScan() async =>
      _client.devices.where((device) => device.deviceType == NetworkManagerDeviceType.wifi).forEach(
        (wirelessDevice) {
          getWifiAccessPoints().clear();
          wirelessDevice.wireless?.requestScan();
        },
      );

  @override
  List<AccessPoint> getWifiAccessPoints() {
    List<AccessPoint> accessPoints = [];

    _client.devices.where((device) => device.deviceType == NetworkManagerDeviceType.wifi).forEach((wirelessDevice) {
      accessPoints = wirelessDevice.wireless!.accessPoints
          .where((a) => a.ssid.isNotEmpty)
          .map((e) => AccessPoint(_client, e, wirelessDevice))
          .toList();
    });

    accessPoints.sort((a, b) => b.strength.compareTo(a.strength));

    return accessPoints;
  }

  @override
  bool get hasWirelessDevice => _client.devices.any((device) => device.deviceType == NetworkManagerDeviceType.wifi);

  @override
  bool get isWifiEnabled => _client.wirelessEnabled;

  @override
  Future<void> turnOffWifi() => _client.setWirelessEnabled(false);

  @override
  Future<void> turnOnWifi() => _client.setWirelessEnabled(true);

  @override
  Future<void> toggleWifi() => _client.setWirelessEnabled(!isWifiEnabled);

  @override
  bool get isWifiConnected => _client.devices
      .where((device) => device.deviceType == NetworkManagerDeviceType.wifi)
      .any((element) => element.wireless!.activeAccessPoint.isNotNull);

  @override
  bool get isWiredConnected => _client.devices
      .where((device) => device.deviceType == NetworkManagerDeviceType.ethernet)
      .any((element) => element.state == NetworkManagerDeviceState.activated);
}

class _NetworkManagerDummy extends NetworkManagerService {
  @override
  Future<void> start() async {}

  @override
  void stop() {}

  @override
  List<AccessPoint> getWifiAccessPoints() => [];

  @override
  Future<void> startWifiScan() => Future.value();

  @override
  bool get hasWirelessDevice => false;

  @override
  bool get isWifiEnabled => false;

  @override
  Future<void> turnOffWifi() => Future.value();

  @override
  Future<void> turnOnWifi() => Future.value();

  @override
  Future<void> toggleWifi() => Future.value();

  @override
  bool get isWifiConnected => false;

  @override
  bool get isWiredConnected => false;
}

class AccessPoint {
  final NetworkManagerClient client;
  final NetworkManagerAccessPoint instance;
  final NetworkManagerDevice device;

  AccessPoint(this.client, this.instance, this.device);

  /// Access Point SSID
  String get ssid => utf8.decode(instance.ssid);

  /// Access Point Strength as Integer
  int get strength => instance.strength;

  /// Access Point encryption status
  bool get isProtected => instance.rsnFlags.isNotEmpty;

  /// Access Point is saved already
  Future<bool> get isSaved async => getSettings().isNotNull; //TODO possibly a better way to check this

  /// Access Point is connected
  bool get isConnected => client.devices
      .where((device) => device.deviceType == NetworkManagerDeviceType.wifi)
      .any((element) => element.wireless!.activeAccessPoint == instance);

  /// Get te connection settings for this access point
  Future<NetworkManagerSettingsConnection?> getSettings() async {
    NetworkManagerSettingsConnection? accessPointSettings;
    var ssid = utf8.decode(instance.ssid);

    var settings = await Future.wait(
      device.availableConnections.map(
        (e) async => {'settings': await e.getSettings(), 'connection': e},
      ),
    );

    for (var element in settings) {
      var s = element['settings'] as dynamic;
      if (s != null) {
        var connection = s['connection'] as Map<String, DBusValue>?;
        if (connection != null) {
          var id = connection['id'];
          if (id != null) {
            if (id.toNative() == ssid) {
              accessPointSettings = element['connection'] as NetworkManagerSettingsConnection;
            }
          }
        }
      }
    }
    return accessPointSettings;
  }

  /// Get the password if it is saved
  Future<String?> getPassword() async {
    var settingsConnection = await getSettings();
    if (settingsConnection != null) {
      var secrets = await settingsConnection.getSecrets('802-11-wireless-security');
      if (secrets.isNotEmpty) {
        var security = secrets['802-11-wireless-security'];
        if (security != null) {
          var psk = security['psk'];
          if (psk != null) {
            return psk.toNative();
          }
        }
      }
    }
    return null;
  }

  /// Connect to this access point
  Future<void> connect() async {
    //TODO improve this and add support for non encrypted networks
    String? password = await getPassword();
    if (password.isNotNull) {
      await client.addAndActivateConnection(device: device, accessPoint: instance, connection: {
        '802-11-wireless-security': {'key-mgmt': const DBusString('wpa-psk'), 'psk': DBusString(password!)}
      });
    }
  }
}

extension on Object? {
  bool get isNull => this == null;
  bool get isNotNull => this != null;
}
