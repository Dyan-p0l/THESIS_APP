import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class AssessmentResult {
  final int seq;
  final double ide1Pf;
  final double ide2Pf;
  final double finalPf;
  final bool sessionValid;
  final int stableSampleCount;
  final int flags;
  final bool clamped;

  const AssessmentResult({
    required this.seq,
    required this.ide1Pf,
    required this.ide2Pf,
    required this.finalPf,
    required this.sessionValid,
    required this.stableSampleCount,
    required this.flags,
    required this.clamped,
  });
}

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;

  BleService._internal() {
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on && _device == null) {
        startAutoConnect();
      }
    });
  }

  final Guid serviceUuid = Guid("6a6e2d3b-2c5f-4d3a-9b41-2c8a9c0a9b10");
  final Guid packetUuid = Guid("6a6e2d3b-2c5f-4d3a-9b41-2c8a9c0a9b11");
  final String targetDeviceName = "FDC1004_IDE";

  static const int flagStableNow = 1 << 0;
  static const int flagIde1Valid = 1 << 1;
  static const int flagIde2Valid = 1 << 2;
  static const int flagSessionValid = 1 << 4;
  static const int flagFinal = 1 << 5;
  static const int flagClamped = 1 << 6;

  static const int _liveMedianWindowSize = 5;
  static const double _emaAlpha = 0.35;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _packetChar;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  Timer? _rssiTimer;
  Timer? _sessionInactivityTimer;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<int> _rssiController =
      StreamController<int>.broadcast();
  final StreamController<double> _capacitanceController =
      StreamController<double>.broadcast();
  final StreamController<bool> _stableController =
      StreamController<bool>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<int> get rssiStream => _rssiController.stream;
  Stream<double> get capacitanceStream => _capacitanceController.stream;
  Stream<bool> get stableStream => _stableController.stream;
  Stream<String> get statusStream => _statusController.stream;

  bool get isConnected => _device != null && _packetChar != null;

  bool _isConnecting = false;
  bool _isArmed = false;
  Duration _sessionTimeout = const Duration(seconds: 20);

  Completer<AssessmentResult>? _pendingFinal;
  int? _lastSeq;

  final List<double> _stableSamples = <double>[];
  final List<double> _liveMedianWindow = <double>[];
  double? _liveEma;

  Future<void> startAutoConnect() async {
    if (_isConnecting || FlutterBluePlus.isScanningNow || isConnected) return;

    await _requestPermissions();
    await _ensureBluetoothOn();
    await _startScan();
  }

  Future<AssessmentResult> startAssessment({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (!isConnected) {
      throw StateError("ESP32 is not connected");
    }

    _cancelPendingAssessment("Replaced by new assessment");
    _sessionTimeout = timeout;
    _isArmed = true;
    _lastSeq = null;
    _stableSamples.clear();
    _liveMedianWindow.clear();
    _liveEma = null;
    _stableController.add(false);
    _statusController.add("Ready. Press the device button to start measuring.");

    _pendingFinal = Completer<AssessmentResult>();
    _resetSessionInactivityTimer();

    return _pendingFinal!.future;
  }

  void cancelAssessment([String reason = "Assessment cancelled"]) {
    _cancelPendingAssessment(reason);
    _isArmed = false;
    _statusController.add("Cancelled");
    _stableController.add(false);
  }

  Future<void> disconnect() async {
    _cancelPendingAssessment("Disconnected");
    _rssiTimer?.cancel();
    await _device?.disconnect();
    _cleanupConnection();
    _connectionController.add(false);
  }

  void dispose() {
    _scanSub?.cancel();
    _connSub?.cancel();
    _notifySub?.cancel();
    _rssiTimer?.cancel();
    _sessionInactivityTimer?.cancel();
    _connectionController.close();
    _rssiController.close();
    _capacitanceController.close();
    _stableController.close();
    _statusController.close();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> _ensureBluetoothOn() async {
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      await FlutterBluePlus.turnOn();
      await FlutterBluePlus.adapterState
          .where((s) => s == BluetoothAdapterState.on)
          .first;
    }
  }

  Future<void> _startScan() async {
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 12),
      withServices: [serviceUuid],
    );

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      for (final r in results) {
        final advName = r.advertisementData.advName;
        final devName = r.device.platformName;
        final matchesName =
            advName == targetDeviceName || devName == targetDeviceName;

        if (matchesName) {
          await FlutterBluePlus.stopScan();
          await _scanSub?.cancel();
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
      _statusController.add("Connected");
    } catch (_) {
      _connectionController.add(false);
      _statusController.add("Connection failed");
      _device = null;
      _isConnecting = false;
      _retry();
      return;
    }

    _connSub?.cancel();
    _connSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _cancelPendingAssessment("Disconnected while waiting for result");
        _cleanupConnection();
        _connectionController.add(false);
        _statusController.add("Disconnected");
        _retry();
      }
    });

    await _discoverServices();
    await _enableNotifications();
    await _readAndEmitRssi();
    _startRssiPolling();
    _isConnecting = false;
  }

  Future<void> _discoverServices() async {
    if (_device == null) return;

    final services = await _device!.discoverServices();
    for (final service in services) {
      if (service.uuid != serviceUuid) continue;
      for (final c in service.characteristics) {
        if (c.uuid == packetUuid) {
          _packetChar = c;
        }
      }
    }

    if (_packetChar == null) {
      throw StateError("Packet characteristic not found");
    }
  }

  Future<void> _enableNotifications() async {
    if (_packetChar == null) return;

    await _packetChar!.setNotifyValue(true);

    _notifySub?.cancel();
    _notifySub = _packetChar!.onValueReceived.listen((value) {
      _handlePacket(value);
    });
  }

  void _handlePacket(List<int> value) {
    if (value.length < 7) return;
    if (!_isArmed) return;

    _resetSessionInactivityTimer();

    final bytes = Uint8List.fromList(value);
    final bd = ByteData.sublistView(bytes);

    final seq = bd.getUint16(0, Endian.little);
    if (_lastSeq == seq) return;
    _lastSeq = seq;

    final ide1mpF = bd.getInt16(2, Endian.little);
    final ide2mpF = bd.getInt16(4, Endian.little);
    final flags = bytes[6];

    final stableNow = (flags & flagStableNow) != 0;
    final ide1Valid = (flags & flagIde1Valid) != 0;
    final ide2Valid = (flags & flagIde2Valid) != 0;
    final sessionValid = (flags & flagSessionValid) != 0;
    final isFinal = (flags & flagFinal) != 0;
    final clamped = (flags & flagClamped) != 0;

    final ide1Pf = ide1mpF / 1000.0;
    final ide2Pf = ide2mpF / 1000.0;
    final packetPf = _combineIdeValues(
      ide1Pf: ide1Pf,
      ide2Pf: ide2Pf,
      ide1Valid: ide1Valid,
      ide2Valid: ide2Valid,
    );

    _stableController.add(stableNow);

    if (!isFinal) {
      if (stableNow && packetPf != null) {
        _stableSamples.add(packetPf);
        final liveFiltered = _applyLiveFlutterFilter(packetPf);
        _capacitanceController.add(liveFiltered);
        _statusController.add("Receiving stable samples...");
      }
      return;
    }

    _sessionInactivityTimer?.cancel();

    final finalPf = _computeFinalFlutterValue(fallbackPacketPf: packetPf);

    _capacitanceController.add(finalPf);
    _stableController.add(sessionValid);
    _statusController.add(
      sessionValid ? "Assessment complete" : "Assessment invalid / timeout",
    );

    if (_pendingFinal != null && !_pendingFinal!.isCompleted) {
      _pendingFinal!.complete(
        AssessmentResult(
          seq: seq,
          ide1Pf: ide1Pf,
          ide2Pf: ide2Pf,
          finalPf: finalPf,
          sessionValid: sessionValid,
          stableSampleCount: _stableSamples.length,
          flags: flags,
          clamped: clamped,
        ),
      );
    }

    _isArmed = false;
  }

  double? _combineIdeValues({
    required double ide1Pf,
    required double ide2Pf,
    required bool ide1Valid,
    required bool ide2Valid,
  }) {
    if (ide1Valid && ide2Valid) return (ide1Pf + ide2Pf) / 2.0;
    if (ide1Valid) return ide1Pf;
    if (ide2Valid) return ide2Pf;
    return null;
  }

  double _applyLiveFlutterFilter(double value) {
    _liveMedianWindow.add(value);
    if (_liveMedianWindow.length > _liveMedianWindowSize) {
      _liveMedianWindow.removeAt(0);
    }

    final median = _median(_liveMedianWindow);
    _liveEma = (_liveEma == null)
        ? median
        : (_emaAlpha * median) + ((1.0 - _emaAlpha) * _liveEma!);

    return _liveEma!;
  }

  double _computeFinalFlutterValue({double? fallbackPacketPf}) {
    if (_stableSamples.isEmpty) return fallbackPacketPf ?? double.nan;
    return _median(_stableSamples);
  }

  double _median(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final n = sorted.length;
    if (n == 0) return double.nan;
    if (n.isOdd) return sorted[n ~/ 2];
    return (sorted[(n ~/ 2) - 1] + sorted[n ~/ 2]) / 2.0;
  }

  void _resetSessionInactivityTimer() {
    _sessionInactivityTimer?.cancel();
    _sessionInactivityTimer = Timer(_sessionTimeout, () {
      if (_pendingFinal != null && !_pendingFinal!.isCompleted) {
        _pendingFinal!.completeError(
          TimeoutException(
            "No sensor packets received within ${_sessionTimeout.inSeconds} seconds",
            _sessionTimeout,
          ),
        );
      }
      _isArmed = false;
      _statusController.add("Assessment timed out");
      _stableController.add(false);
    });
  }

  void _cancelPendingAssessment(String reason) {
    _sessionInactivityTimer?.cancel();
    if (_pendingFinal != null && !_pendingFinal!.isCompleted) {
      _pendingFinal!.completeError(StateError(reason));
    }
    _pendingFinal = null;
    _isArmed = false;
    _stableSamples.clear();
    _liveMedianWindow.clear();
    _liveEma = null;
  }

  void _startRssiPolling() {
    _rssiTimer?.cancel();
    _rssiTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _readAndEmitRssi();
    });
  }

  Future<void> _readAndEmitRssi() async {
    if (_device == null) return;
    try {
      final rssi = await _device!.readRssi();
      _rssiController.add(rssi);
    } catch (_) {}
  }

  void _cleanupConnection() {
    _scanSub?.cancel();
    _connSub?.cancel();
    _notifySub?.cancel();
    _rssiTimer?.cancel();
    _packetChar = null;
    _device = null;
    _isConnecting = false;
  }

  void _retry() {
    Future.delayed(const Duration(seconds: 2), () {
      startAutoConnect();
    });
  }
}
