import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService {
  // Singleton
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal() {
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on && _device == null) {
        startAutoConnect();
      }
    });
  }

  // Note: We no longer need a local instance variable for FlutterBluePlus

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;

  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _notificationSubscription;

  final Guid serviceUuid = Guid("6e400001-b5a3-f393-e0a9-e50e24dcca9e");
  final Guid characteristicUuid = Guid("6e400002-b5a3-f393-e0a9-e50e24dcca9e");
  final String targetDeviceName = "ESP32_CapSensor_Test";

  final StreamController<double> _capacitanceController =
      StreamController.broadcast();
  final StreamController<bool> _connectionController =
      StreamController.broadcast();

  Stream<double> get capacitanceStream => _capacitanceController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool _isConnecting = false;

  Future<void> startAutoConnect() async {
    // Check if already scanning or connecting
    if (FlutterBluePlus.isScanningNow || _isConnecting) return;

    await _requestPermissions();
    await _ensureBluetoothOn();
    _startScan();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> _ensureBluetoothOn() async {
    BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;

    if (state != BluetoothAdapterState.on) {
      // Show system popup to enable Bluetooth
      await FlutterBluePlus.turnOn();

      // Wait until Bluetooth becomes ON
      await FlutterBluePlus.adapterState
          .where((s) => s == BluetoothAdapterState.on)
          .first;
    }
  }

  void _startScan() async {
    // Corrected: startScan is a static method
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      withServices: [serviceUuid],
    );

    // Corrected: scanResults is a static getter
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        // Use platformName in newer versions
        if (r.device.platformName == targetDeviceName) {
          await FlutterBluePlus.stopScan();
          _scanSubscription?.cancel();
          await _connect(r.device);
          break;
        }
      }
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    if (_isConnecting) return;
    _isConnecting = true;
    _device = device;

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectionController.add(true);
    } catch (e) {
      _connectionController.add(false);
      _isConnecting = false;
      _retry();
      return;
    }

    _connectionSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _connectionController.add(false);
        _cleanupConnection();
        _retry();
      }
    });

    await _discoverServices();
    _isConnecting = false;
  }

  Future<void> _discoverServices() async {
    if (_device == null) return;
    List<BluetoothService> services = await _device!.discoverServices();
    for (var service in services) {
      if (service.uuid == serviceUuid) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid == characteristicUuid) {
            _characteristic = characteristic;
            await _enableNotifications();
            return;
          }
        }
      }
    }
  }

  Future<void> _enableNotifications() async {
    if (_characteristic == null) return;

    await _characteristic!.setNotifyValue(true);
    // Corrected: Use lastValueStream or onValueReceived
    _notificationSubscription = _characteristic!.onValueReceived.listen((
      value,
    ) {
      String raw = String.fromCharCodes(value);
      final match = RegExp(r'\d+').firstMatch(raw);
      if (match != null) {
        double cap = double.parse(match.group(0)!);
        _capacitanceController.add(cap);
      }
    });
  }

  void _retry() {
    _isConnecting = false;
    _device = null;
    Future.delayed(const Duration(seconds: 2), () => startAutoConnect());
  }

  void _cleanupConnection() {
    _connectionSubscription?.cancel();
    _notificationSubscription?.cancel();
    _characteristic = null;
    _device = null;
  }

  Future<void> disconnect() async {
    await _device?.disconnect();
    _connectionController.add(false);
    _cleanupConnection();
  }

  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _notificationSubscription?.cancel();
    _capacitanceController.close();
    _connectionController.close();
  }
}
