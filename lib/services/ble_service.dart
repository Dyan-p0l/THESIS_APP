import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class AssessmentResult {
  final int seq;
  final int
  elapsedMs; // ESP32 packet doesn't include elapsed; kept for compatibility (0)
  final double ide1Pf;
  final double ide2Pf;
  final double finalPf; // one value for UI
  final bool
  stable; // stableNow bit0 (on FINAL packet this should represent success/fail)
  final int flags;

  AssessmentResult({
    required this.seq,
    required this.elapsedMs,
    required this.ide1Pf,
    required this.ide2Pf,
    required this.finalPf,
    required this.stable,
    required this.flags,
  });
}

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

  // ===== Device / GATT IDs (match ESP32) =====
  final Guid serviceUuid = Guid("6a6e2d3b-2c5f-4d3a-9b41-2c8a9c0a9b10");
  final Guid packetUuid = Guid(
    "6a6e2d3b-2c5f-4d3a-9b41-2c8a9c0a9b11",
  ); // Notify
  final Guid controlUuid = Guid(
    "6a6e2d3b-2c5f-4d3a-9b41-2c8a9c0a9b12",
  ); // Write START/STOP
  final String targetDeviceName = "FDC1004_IDE";

  BluetoothDevice? _device;
  BluetoothCharacteristic? _pktChar;
  BluetoothCharacteristic? _ctrlChar;

  StreamSubscription? _scanSub;
  StreamSubscription? _connSub;
  StreamSubscription? _notifySub;

  final StreamController<double> _capacitanceController =
      StreamController.broadcast();
  final StreamController<bool> _connectionController =
      StreamController.broadcast();
  final StreamController<bool> _stableController = StreamController.broadcast();

  Stream<double> get capacitanceStream => _capacitanceController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<bool> get stableStream => _stableController.stream;

  bool _isConnecting = false;

  Completer<AssessmentResult>? _pendingFinal;
  Timer? _finalTimeout;

  // ===== ESP32 flags bits =====
  static const int FLAG_STABLE_NOW = 1 << 0;
  static const int FLAG_IDE1_VALID = 1 << 1;
  static const int FLAG_IDE2_VALID = 1 << 2;
  static const int FLAG_FINAL = 1 << 5;

  // ===== Public API =====

  Future<void> startAutoConnect() async {
    if (FlutterBluePlus.isScanningNow || _isConnecting) return;
    await _requestPermissions();
    await _ensureBluetoothOn();
    _startScan();
  }

  /// Call this when user presses Start Assessment.
  /// It writes START (0x01) to ESP32 control characteristic, then waits for FINAL (flags bit5).
  Future<AssessmentResult> startAssessment({
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (!isConnected) {
      throw StateError("Not connected to device");
    }
    if (_ctrlChar == null) {
      throw StateError("Control characteristic not found");
    }

    // Clear any previous stable UI indicator during idle
    _stableController.add(false);

    // Start waiting for FINAL first (so you don't miss a very fast FINAL)
    final future = waitForFinal(timeout: timeout);

    // Send START command (0x01)
    // Use withoutResponse if available; if it fails, fall back to normal write.
    try {
      await _ctrlChar!.write([0x01], withoutResponse: true);
    } catch (_) {
      await _ctrlChar!.write([0x01], withoutResponse: false);
    }

    return future;
  }

  /// Optional: cancel measurement early (STOP=0x00).
  Future<void> stopAssessment() async {
    if (_ctrlChar == null) return;
    try {
      await _ctrlChar!.write([0x00], withoutResponse: true);
    } catch (_) {
      await _ctrlChar!.write([0x00], withoutResponse: false);
    }
  }

  bool get isConnected => _device != null;

  Future<void> disconnect() async {
    await _device?.disconnect();
    _connectionController.add(false);
    _cleanupConnection();
  }

  void dispose() {
    _scanSub?.cancel();
    _connSub?.cancel();
    _notifySub?.cancel();
    _capacitanceController.close();
    _connectionController.close();
    _stableController.close();
  }

  // ===== Internals =====

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

  void _startScan() async {
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      withServices: [serviceUuid],
    );

    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      for (final r in results) {
        if (r.device.platformName == targetDeviceName) {
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
    } catch (_) {
      _connectionController.add(false);
      _isConnecting = false;
      _retry();
      return;
    }

    _connSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _connectionController.add(false);

        // fail any pending wait
        _finalTimeout?.cancel();
        if (_pendingFinal != null && !_pendingFinal!.isCompleted) {
          _pendingFinal!.completeError(
            StateError("Disconnected while waiting for FINAL packet"),
          );
        }

        _cleanupConnection();
        _retry();
      }
    });

    await _discoverServicesAndChars();
    _isConnecting = false;
  }

  Future<void> _discoverServicesAndChars() async {
    if (_device == null) return;

    final services = await _device!.discoverServices();

    for (final s in services) {
      if (s.uuid != serviceUuid) continue;

      for (final c in s.characteristics) {
        if (c.uuid == packetUuid) {
          _pktChar = c;
        } else if (c.uuid == controlUuid) {
          _ctrlChar = c;
        }
      }
    }

    if (_pktChar == null) {
      throw StateError("Packet characteristic not found");
    }
    if (_ctrlChar == null) {
      // Not fatal for live view, but fatal for on-demand startAssessment()
      // Keep it nullable; startAssessment() will throw if missing.
    }

    await _enableNotifications();
  }

  Future<AssessmentResult> waitForFinal({
    Duration timeout = const Duration(seconds: 25),
  }) {
    _finalTimeout?.cancel();
    _pendingFinal?.completeError(StateError("Cancelled by new waitForFinal()"));
    _pendingFinal = Completer<AssessmentResult>();

    _finalTimeout = Timer(timeout, () {
      if (_pendingFinal != null && !_pendingFinal!.isCompleted) {
        _pendingFinal!.completeError(
          TimeoutException("No FINAL packet received", timeout),
        );
      }
    });

    return _pendingFinal!.future;
  }

  Future<void> _enableNotifications() async {
    if (_pktChar == null) return;

    await _pktChar!.setNotifyValue(true);

    _notifySub?.cancel();
    _notifySub = _pktChar!.onValueReceived.listen((value) {
      // ESP32 packet is 7 bytes:
      // seq(uint16), ide1(int16), ide2(int16), flags(uint8)
      if (value.length < 7) return;

      final bytes = Uint8List.fromList(value);
      final bd = ByteData.sublistView(bytes);

      final int seq = bd.getUint16(0, Endian.little);
      final int ide1mpF = bd.getInt16(2, Endian.little);
      final int ide2mpF = bd.getInt16(4, Endian.little);
      final int flags = bytes[6];

      final bool stableNow = (flags & FLAG_STABLE_NOW) != 0;
      final bool ide1Valid = (flags & FLAG_IDE1_VALID) != 0;
      final bool ide2Valid = (flags & FLAG_IDE2_VALID) != 0;
      final bool isFinal = (flags & FLAG_FINAL) != 0;

      // During idle, ESP32 should not notify; when measuring it may toggle stableNow.
      _stableController.add(stableNow);

      final double ide1Pf = ide1mpF / 1000.0;
      final double ide2Pf = ide2mpF / 1000.0;

      double? finalPf;
      if (ide1Valid && ide2Valid) {
        finalPf = (ide1Pf + ide2Pf) / 2.0;
      } else if (ide1Valid) {
        finalPf = ide1Pf;
      } else if (ide2Valid) {
        finalPf = ide2Pf;
      }

      // In your new on-demand design, ESP32 should only send FINAL once.
      // Still safe to update live display when a packet arrives.
      if (finalPf != null) {
        _capacitanceController.add(finalPf);
      }

      // Resolve the waiting Start Assessment when FINAL bit arrives.
      if (isFinal && _pendingFinal != null && !_pendingFinal!.isCompleted) {
        _finalTimeout?.cancel();
        _pendingFinal!.complete(
          AssessmentResult(
            seq: seq,
            elapsedMs: 0,
            ide1Pf: ide1Pf,
            ide2Pf: ide2Pf,
            finalPf: finalPf ?? double.nan,
            stable: stableNow,
            flags: flags,
          ),
        );
      }
    });
  }

  void _retry() {
    _isConnecting = false;
    _device = null;
    Future.delayed(const Duration(seconds: 2), () => startAutoConnect());
  }

  void _cleanupConnection() {
    _connSub?.cancel();
    _notifySub?.cancel();
    _pktChar = null;
    _ctrlChar = null;
    _device = null;
  }
}
