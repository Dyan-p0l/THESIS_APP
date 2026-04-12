import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class AssessmentResult {
  final int seq;
  final double idePf;
  final double finalPf;
  final bool sessionValid;
  final int stableSampleCount;
  final int flags;
  final bool clamped;

  const AssessmentResult({
    required this.seq,
    required this.idePf,
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
    // If Bluetooth itself turns back on, try to reconnect automatically.
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on && !_isConnecting && !isConnected) {
        startAutoConnect();
      }
    });
  }

  final Guid serviceUuid = Guid("6a6e2d3b-2c5f-4d3a-9b41-2c8a9c0a9b10");
  final Guid packetUuid = Guid("6a6e2d3b-2c5f-4d3a-9b41-2c8a9c0a9b11");
  final String targetDeviceName = "FDC1004_IDE";

  // Packet flags — single-IDE layout
  // Bit 0 : sensor reading is stable
  // Bit 1 : IDE reading is valid
  // Bit 4 : session as a whole is valid
  // Bit 5 : this is the final packet for the session
  // Bit 6 : value was clamped by firmware
  static const int flagStableNow    = 1 << 0;
  static const int flagIdeValid     = 1 << 1;
  static const int flagSessionValid = 1 << 4;
  static const int flagFinal        = 1 << 5;
  static const int flagClamped      = 1 << 6;

  static const int _liveMedianWindowSize = 5;
  static const double _emaAlpha = 0.35;
  static const Duration _scanTimeout = Duration(seconds: 12);
  static const Duration _retryDelay = Duration(seconds: 2);

  // Minimum packet size for the new layout:
  //   uint16_t seq    → 2 bytes
  //   int16_t  ide_mpF → 2 bytes
  //   uint8_t  flags  → 1 byte
  //   total           → 5 bytes
  static const int _minPacketLength = 5;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _packetChar;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<bool>? _isScanningSub;
  Timer? _rssiTimer;
  Timer? _sessionInactivityTimer;
  Timer? _retryTimer;

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

  bool _connected = false;
  bool get isConnected => _connected;

  bool _isConnecting = false;
  bool _isArmed = false;
  bool _disposed = false;
  Duration _sessionTimeout = const Duration(seconds: 20);

  Completer<AssessmentResult>? _pendingFinal;
  int? _lastSeq;

  final List<double> _stableSamples = <double>[];
  final List<double> _liveMedianWindow = <double>[];
  double? _liveEma;

  Future<void> startAutoConnect() async {
    if (_disposed || _isConnecting || FlutterBluePlus.isScanningNow) {
      return;
    }

    if (_device != null && !_connected) {
      _cleanupConnection();
    }

    if (isConnected) {
      return;
    }

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
    _retryTimer?.cancel();

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    try {
      await _device?.disconnect();
    } catch (_) {}

    _cleanupConnection();
    _connectionController.add(false);
    _statusController.add("Disconnected");
  }

  void dispose() {
    _disposed = true;
    _cleanupConnection();
    _sessionInactivityTimer?.cancel();
    _retryTimer?.cancel();
    _connectionController.close();
    _rssiController.close();
    _capacitanceController.close();
    _stableController.close();
    _statusController.close();
  }

  // ---------------------------------------------------------------------------
  // BLE plumbing
  // ---------------------------------------------------------------------------

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
    if (_disposed || _isConnecting || isConnected) return;

    _statusController.add("Scanning for device...");

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    _scanSub?.cancel();
    _isScanningSub?.cancel();

    await FlutterBluePlus.startScan(timeout: _scanTimeout);

    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      if (_isConnecting || isConnected) return;

      for (final r in results) {
        final advName = r.advertisementData.advName;
        final devName = r.device.platformName;
        final matchesName =
            advName == targetDeviceName || devName == targetDeviceName;

        if (!matchesName) continue;

        _statusController.add("Device found. Connecting...");

        try {
          await FlutterBluePlus.stopScan();
        } catch (_) {}

        await _scanSub?.cancel();
        _scanSub = null;
        await _connect(r.device);
        break;
      }
    });

    _isScanningSub = FlutterBluePlus.isScanning.listen((isScanning) {
      if (!isScanning && !isConnected && !_isConnecting) {
        _scheduleRetry("scan stopped without connection");
      }
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    if (_disposed || _isConnecting) return;
    _retryTimer?.cancel();
    _isConnecting = true;
    _connected = false;
    _device = device;

    try {
      await device.disconnect().catchError((_) {});
      await Future.delayed(const Duration(milliseconds: 150));
      await device.connect(timeout: const Duration(seconds: 10));

      _connSub?.cancel();
      _connSub = device.connectionState.listen((state) {
        final connectedNow = state == BluetoothConnectionState.connected;
        _connected = connectedNow;
        _connectionController.add(connectedNow);

        if (state == BluetoothConnectionState.disconnected) {
          _cancelPendingAssessment("Disconnected while waiting for result");
          _cleanupConnection();
          _connectionController.add(false);
          _statusController.add("Disconnected");
          _scheduleRetry("device disconnected");
        }
      });

      await _discoverServices();
      await _enableNotifications();
      await _readAndEmitRssi();
      _startRssiPolling();

      _connected = true;
      _connectionController.add(true);
      _statusController.add("Connected");
    } catch (e) {
      _connected = false;
      _connectionController.add(false);
      _statusController.add("Connection failed");
      await _hardCleanupAfterConnectFailure();
      _scheduleRetry("connect/discovery failure: $e");
      return;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> _discoverServices() async {
    if (_device == null) return;

    _packetChar = null;
    final services = await _device!.discoverServices();

    for (final service in services) {
      if (service.uuid != serviceUuid) continue;
      for (final c in service.characteristics) {
        if (c.uuid == packetUuid) {
          _packetChar = c;
          break;
        }
      }
    }

    if (_packetChar == null) {
      throw StateError("Packet characteristic not found");
    }
  }

  Future<void> _enableNotifications() async {
    if (_packetChar == null) {
      throw StateError("Packet characteristic missing before notify setup");
    }

    await _notifySub?.cancel();
    _notifySub = null;

    await _packetChar!.setNotifyValue(true);
    _notifySub = _packetChar!.onValueReceived.listen(_handlePacket);
  }

  // ---------------------------------------------------------------------------
  // Packet parsing — new single-IDE layout
  //
  //   Offset  Size  Field
  //   0       2     seq      (uint16, little-endian)
  //   2       2     ide_mpF  (int16,  little-endian)  — millipicofarads
  //   4       1     flags    (uint8)
  // ---------------------------------------------------------------------------
  void _handlePacket(List<int> value) {
    if (value.length < _minPacketLength) return;
    if (!_isArmed) return;

    _resetSessionInactivityTimer();

    final bytes = Uint8List.fromList(value);
    final bd = ByteData.sublistView(bytes);

    final seq      = bd.getUint16(0, Endian.little);
    final ideMpF   = bd.getInt16(2, Endian.little);
    final flags    = bytes[4];

    // Deduplicate packets with the same sequence number.
    if (_lastSeq == seq) return;
    _lastSeq = seq;

    final stableNow    = (flags & flagStableNow)    != 0;
    final ideValid     = (flags & flagIdeValid)      != 0;
    final sessionValid = (flags & flagSessionValid)  != 0;
    final isFinal      = (flags & flagFinal)         != 0;
    final clamped      = (flags & flagClamped)       != 0;

    final idePf = ideMpF / 1000.0;

    _stableController.add(stableNow);

    if (!isFinal) {
      if (stableNow && ideValid) {
        _stableSamples.add(idePf);
        final liveFiltered = _applyLiveFlutterFilter(idePf);
        _capacitanceController.add(liveFiltered);
        _statusController.add("Receiving stable samples...");
      }
      return;
    }

    // --- Final packet ---
    _sessionInactivityTimer?.cancel();

    final finalPf = _computeFinalFlutterValue(
      fallbackPacketPf: ideValid ? idePf : null,
    );

    _capacitanceController.add(finalPf);
    _stableController.add(sessionValid);
    _statusController.add(
      sessionValid ? "Assessment complete" : "Assessment invalid / timeout",
    );

    if (_pendingFinal != null && !_pendingFinal!.isCompleted) {
      _pendingFinal!.complete(
        AssessmentResult(
          seq: seq,
          idePf: idePf,
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

  // ---------------------------------------------------------------------------
  // Signal filtering helpers (unchanged)
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Session / inactivity timer helpers
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // RSSI polling
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Connection cleanup helpers
  // ---------------------------------------------------------------------------

  Future<void> _hardCleanupAfterConnectFailure() async {
    _notifySub?.cancel();
    _notifySub = null;
    _connSub?.cancel();
    _connSub = null;
    _rssiTimer?.cancel();
    _packetChar = null;
    _connected = false;

    try {
      await _device?.disconnect();
    } catch (_) {}

    _device = null;
  }

  void _cleanupConnection() {
    _scanSub?.cancel();
    _scanSub = null;
    _connSub?.cancel();
    _connSub = null;
    _notifySub?.cancel();
    _notifySub = null;
    _isScanningSub?.cancel();
    _isScanningSub = null;
    _rssiTimer?.cancel();
    _rssiTimer = null;
    _packetChar = null;
    _device = null;
    _connected = false;
    _isConnecting = false;
  }

  void _scheduleRetry(String reason) {
    if (_disposed || _isConnecting || isConnected) return;

    _retryTimer?.cancel();
    _statusController.add("Retrying BLE connection...");
    _retryTimer = Timer(_retryDelay, () {
      if (_disposed || _isConnecting || isConnected) return;
      startAutoConnect();
    });
  }
}