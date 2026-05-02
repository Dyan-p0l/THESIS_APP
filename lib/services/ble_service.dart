import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class AssessmentResult {
  final int seq;
  final double idePf;
  final double ideDiffPf;
  final double finalPf;
  final double finalIdeDiffPf;
  final bool sessionValid;
  final int stableSampleCount;
  final int flags;
  final bool clamped;

  const AssessmentResult({
    required this.seq,
    required this.idePf,
    required this.ideDiffPf,
    required this.finalPf,
    required this.finalIdeDiffPf,
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
      if (state == BluetoothAdapterState.on &&
          !_isConnecting &&
          !isConnected &&
          autoReconnectEnabled) {
        // ✅ respect the toggle
        startAutoConnect();
      }
    });
  }

  final Guid serviceUuid = Guid("6a6e2d3b-2c5f-4d3a-9b41-2c8a9c0a9b10");
  final Guid packetUuid = Guid("6a6e2d3b-2c5f-4d3a-9b41-2c8a9c0a9b11");
  final Guid cmdUuid = Guid("6a6e2d3b-2c5f-4d3a-9b41-2c8a9c0a9b12");
  static const int _manufacturerId =
      0x4B50; // matches BLE_MANUFACTURER_ID in firmware

  // Optional: read the firmware sig byte if you want version checks later
  static const int _firmwareSig = 0x01;

  // Packet flags — single-IDE layout
  // Bit 0 : sensor reading is stable
  // Bit 1 : IDE reading is valid
  // Bit 4 : session as a whole is valid
  // Bit 5 : this is the final packet for the session
  // Bit 6 : value was clamped by firmware
  static const int flagStableNow = 1 << 0;
  static const int flagIdeValid = 1 << 1;
  static const int flagSessionValid = 1 << 4;
  static const int flagFinal = 1 << 5;
  static const int flagClamped = 1 << 6;
  static const int flagCalibration = 1 << 7;

  static const int _liveMedianWindowSize = 5;
  static const double _emaAlpha = 0.35;
  static const Duration _scanTimeout = Duration(seconds: 12);
  static const Duration _retryDelay = Duration(seconds: 2);

  static const int cmdFresh = 0;
  static const int cmdModerate = 1;
  static const int cmdSpoiled = 2;
  static const int cmdClear = 0xFF;
  static const int cmdRecalibrate = 0xFE;

  // Packet layout:
  //
  //   Offset  Size  Field
  //   0       2     seq           (uint16, little-endian)
  //   2       2     ide_mpF       (int16,  little-endian)
  //   4       2     ideDiff_mpF   (int16,  little-endian)
  //   6       1     flags         (uint8)
  static const int _minPacketLength = 7;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _packetChar;
  BluetoothCharacteristic? _cmdChar;

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
  final StreamController<double> _calibrationController =
      StreamController<double>.broadcast();
  final StreamController<double> _ideDiffController =
      StreamController<double>.broadcast();

  double? _latestCalibrationPf;
  double? get latestCalibrationPf => _latestCalibrationPf;
  double? _latestCalibrationDiffPf;
  double? get latestCalibrationDiffPf => _latestCalibrationDiffPf;

  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<int> get rssiStream => _rssiController.stream;
  Stream<double> get capacitanceStream => _capacitanceController.stream;
  Stream<bool> get stableStream => _stableController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<double> get calibrationStream => _calibrationController.stream;
  Stream<double> get ideDiffStream => _ideDiffController.stream;

  bool _connected = false;
  bool get isConnected => _connected;
  bool autoReconnectEnabled = true; // honoured by _scheduleRetry
  String? _connectedDeviceName; // captured at connect time
  String? get connectedDeviceName => _connectedDeviceName; // exposed to UI
  bool _isConnecting = false;
  bool _isArmed = false;
  bool _disposed = false;
  Duration _sessionTimeout = const Duration(seconds: 20);

  Completer<AssessmentResult>? _pendingFinal;
  int? _lastSeq;

  final List<double> _stableSamples = <double>[];
  final List<double> _stableIdeDiffSamples = <double>[];
  final List<double> _liveMedianWindow = <double>[];
  double? _liveEma;

  Future<void> sendRecalibrate() async {
    if (!isConnected || _cmdChar == null) return;
    try {
      await _cmdChar!.write([cmdRecalibrate], withoutResponse: true);
    } catch (e) {
      print('[BLE] sendRecalibrate failed: $e');
    }
  }

  Future<void> startAutoConnect() async {
    // Guard against duplicate scans / overlapping connect attempts.
    if (_disposed || _isConnecting || FlutterBluePlus.isScanningNow) {
      return;
    }

    // Clear stale BLE references left behind by app exit, failed connect,
    // or OS-level disconnects before starting a fresh reconnect attempt.
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
    _stableIdeDiffSamples.clear();
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
    _statusController.add(
      "Device Detached from Fish Surface. Session Cancelled",
    );
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
    _calibrationController.close();
    _ideDiffController.close();
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
        final mfrData = r.advertisementData.manufacturerData;
        final bool isOurDevice = mfrData.containsKey(_manufacturerId);
        if (!isOurDevice) continue;

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

  static bool isOurDevice(ScanResult r) =>
      r.advertisementData.manufacturerData.containsKey(_manufacturerId);

  // Optional: read firmware version from the payload
  static int? firmwareVersion(ScanResult r) {
    final payload = r.advertisementData.manufacturerData[_manufacturerId];
    if (payload == null || payload.isEmpty) return null;
    return payload[0]; // first byte after the 2-byte ID is BLE_FIRMWARE_SIG
  }

  Future<void> _connect(BluetoothDevice device) async {
    if (_disposed || _isConnecting) return;
    _retryTimer?.cancel();
    _isConnecting = true;
    _connected = false;
    // Store the current target device only for this connection attempt.
    _device = device;

    try {
      await device.disconnect().catchError((_) {});
      await Future.delayed(const Duration(milliseconds: 150));
      await device.connect(timeout: const Duration(seconds: 10));

      _connectedDeviceName = device.platformName.isNotEmpty
          ? device.platformName
          : null;
      _connSub?.cancel();
      _connSub = device.connectionState.listen((state) {
        // Track the true BLE link state from the plugin instead of inferring it
        // from cached object references.
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

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (_isConnecting) return;

    _statusController.add("Connecting to selected device...");

    // Stop any ongoing scan
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    // Clean old connection
    await disconnect();

    // Connect using the SAME internal pipeline
    await _connect(device);
  }

  Future<void> _discoverServices() async {
    if (_device == null) return;

    _packetChar = null;
    final services = await _device!.discoverServices();

    for (final service in services) {
      if (service.uuid != serviceUuid) continue;
      for (final c in service.characteristics) {
        if (c.uuid == packetUuid) _packetChar = c;
        if (c.uuid == cmdUuid) _cmdChar = c;
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
  // Packet parsing — 7-byte single-IDE layout
  //
  //   Offset  Size  Field
  //   0       2     seq           (uint16, little-endian)
  //   2       2     ide_mpF       (int16, little-endian)
  //   4       2     ideDiff_mpF   (int16, little-endian)
  //   6       1     flags         (uint8)
  // ---------------------------------------------------------------------------
  void _handlePacket(List<int> value) {
    if (value.length < _minPacketLength) return;

    final bytes = Uint8List.fromList(value);
    final bd = ByteData.sublistView(bytes);

    final seq = bd.getUint16(0, Endian.little);
    final ideMpF = bd.getInt16(2, Endian.little);
    final ideDiffMpF = bd.getInt16(4, Endian.little);
    final flags = bytes[6];

    if (_lastSeq == seq) return;
    _lastSeq = seq;

    final stableNow = (flags & flagStableNow) != 0;
    final ideValid = (flags & flagIdeValid) != 0;
    final sessionValid = (flags & flagSessionValid) != 0;
    final isFinal = (flags & flagFinal) != 0;
    final clamped = (flags & flagClamped) != 0;

    // If you kept the calibration packet support:
    final isCalibration = (flags & flagCalibration) != 0;

    final idePf = ideMpF / 1000.0;
    final ideDiffPf = ideDiffMpF / 1000.0;

    // If you kept calibration support, handle it here before !_isArmed check.
    if (isCalibration) {
      if (ideValid) {
        _latestCalibrationPf = idePf;
        _latestCalibrationDiffPf = ideDiffPf;

        _calibrationController.add(idePf);
        _ideDiffController.add(ideDiffPf);

        _statusController.add("Calibration baseline received");
      }
      return;
    }

    if (!_isArmed) return;

    _resetSessionInactivityTimer();
    _stableController.add(stableNow);

    if (!isFinal) {
      if (stableNow && ideValid) {
        _stableSamples.add(idePf);
        _stableIdeDiffSamples.add(ideDiffPf);

        final liveFiltered = _applyLiveFlutterFilter(idePf);
        _capacitanceController.add(liveFiltered);
        _ideDiffController.add(ideDiffPf);

        _statusController.add("Receiving stable samples...");
      }
      return;
    }

    _sessionInactivityTimer?.cancel();

    final finalPf = _computeFinalFlutterValue(
      fallbackPacketPf: ideValid ? idePf : null,
    );

    final finalIdeDiffPf = _computeFinalIdeDiffFlutterValue(
      fallbackPacketPf: ideValid ? ideDiffPf : null,
    );

    _capacitanceController.add(finalPf);
    _ideDiffController.add(finalIdeDiffPf);
    _stableController.add(sessionValid);
    _statusController.add(
      sessionValid ? "Assessment complete" : "Assessment invalid / timeout",
    );

    if (_pendingFinal != null && !_pendingFinal!.isCompleted) {
      _pendingFinal!.complete(
        AssessmentResult(
          seq: seq,
          idePf: idePf,
          ideDiffPf: ideDiffPf,
          finalPf: finalPf,
          finalIdeDiffPf: finalIdeDiffPf,
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
  // Signal filtering helpers
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

  double _computeFinalIdeDiffFlutterValue({double? fallbackPacketPf}) {
    if (_stableIdeDiffSamples.isEmpty) return fallbackPacketPf ?? double.nan;
    return _median(_stableIdeDiffSamples);
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
    _stableIdeDiffSamples.clear();
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

  /// Sends a classification label (0=fresh, 1=moderate, 2=spoiled, 0xFF=clear)
  /// to the ESP32 so it can light the correct indicator LED.
  Future<void> sendClassification(int label) async {
    if (!isConnected || _cmdChar == null) return;
    try {
      await _cmdChar!.write(
        [label & 0xFF],
        withoutResponse: true, // matches PROPERTY_WRITE_NR on firmware side
      );
    } catch (e) {
      print('[BLE] sendClassification failed: $e');
    }
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
    _cmdChar = null;
    _connected = false;

    try {
      await _device?.disconnect();
    } catch (_) {}

    _device = null;
  }

  void _cleanupConnection() {
    // Fully clear subscriptions and cached handles so the next reconnect starts
    // from a known clean state.
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
    _cmdChar = null;
    _device = null;
    _connected = false;
    _isConnecting = false;
    _connectedDeviceName = null;
  }

  void _scheduleRetry(String reason) {
    if (_disposed || _isConnecting || isConnected) return;
    if (!autoReconnectEnabled) return; // ← NEW: respect the UI toggle

    _retryTimer?.cancel();
    _statusController.add("Retrying BLE connection...");
    _retryTimer = Timer(_retryDelay, () {
      if (_disposed || _isConnecting || isConnected) return;
      if (!autoReconnectEnabled) return; // ← double-check in case it changed
      startAutoConnect();
    });
  }
}
