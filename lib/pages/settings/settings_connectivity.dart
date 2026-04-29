import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ble_service.dart';

// ============================================================
// PREFS KEYS + MODEL
// ============================================================
class ConnectivityPrefsKeys {
  static const autoConnectOnStartup = 'connectivity_auto_connect';
  static const autoReconnectIfDisconnected = 'connectivity_auto_reconnect';
}

class ConnectivityPrefs {
  final bool autoConnectOnStartup;
  final bool autoReconnectIfDisconnected;

  const ConnectivityPrefs({
    this.autoConnectOnStartup = true,
    this.autoReconnectIfDisconnected = true,
  });

  ConnectivityPrefs copyWith({
    bool? autoConnectOnStartup,
    bool? autoReconnectIfDisconnected,
  }) => ConnectivityPrefs(
    autoConnectOnStartup: autoConnectOnStartup ?? this.autoConnectOnStartup,
    autoReconnectIfDisconnected:
        autoReconnectIfDisconnected ?? this.autoReconnectIfDisconnected,
  );

  static Future<ConnectivityPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ConnectivityPrefs(
      autoConnectOnStartup:
          prefs.getBool(ConnectivityPrefsKeys.autoConnectOnStartup) ?? true,
      autoReconnectIfDisconnected:
          prefs.getBool(ConnectivityPrefsKeys.autoReconnectIfDisconnected) ??
          true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      ConnectivityPrefsKeys.autoConnectOnStartup,
      autoConnectOnStartup,
    );
    await prefs.setBool(
      ConnectivityPrefsKeys.autoReconnectIfDisconnected,
      autoReconnectIfDisconnected,
    );
  }
}

// ============================================================
// CONNECTIVITY DATA MODEL
// ============================================================
class ConnectivityData {
  final bool isBluetoothConnected;
  final bool autoConnectOnStartup;
  final bool autoReconnectIfDisconnected;
  final ConnectedDevice? connectedDevice;
  final int otherDevicesCount;

  const ConnectivityData({
    this.isBluetoothConnected = false,
    this.autoConnectOnStartup = false,
    this.autoReconnectIfDisconnected = false,
    this.connectedDevice,
    this.otherDevicesCount = 0,
  });
}

class ConnectedDevice {
  final String name;
  final String uuid;

  const ConnectedDevice({required this.name, required this.uuid});
}

// ============================================================
// RESPONSIVE HELPERS
// ============================================================

double _rfs(BuildContext context, double base) {
  final width = MediaQuery.of(context).size.width;
  final scale = (width / 390.0).clamp(0.8, 1.2);
  return base * scale;
}

double _rs(BuildContext context, double base) {
  final width = MediaQuery.of(context).size.width;
  final scale = (width / 390.0).clamp(0.75, 1.3);
  return base * scale;
}

// ============================================================
// CONNECTIVITY SCREEN
// ============================================================
class SettingsConnectivityScreen extends StatefulWidget {
  final BleService? bleService;
  final ValueChanged<bool>? onAutoConnectToggled;
  final ValueChanged<bool>? onAutoReconnectToggled;
  final VoidCallback? onOtherDevicesTapped;

  const SettingsConnectivityScreen({
    super.key,
    this.bleService,
    this.onAutoConnectToggled,
    this.onAutoReconnectToggled,
    this.onOtherDevicesTapped,
  });

  @override
  State<SettingsConnectivityScreen> createState() =>
      _SettingsConnectivityScreenState();
}

class _SettingsConnectivityScreenState
    extends State<SettingsConnectivityScreen> {
  bool _autoConnect = false;
  bool _autoReconnect = false;
  bool _loading = true;

  bool _isBluetoothConnected = false;
  ConnectedDevice? _connectedDevice;

  StreamSubscription<bool>? _connectionSub;

  BleService get _ble => widget.bleService ?? BleService();

  String get _deviceUuid => _ble.serviceUuid.toString();

  @override
  void initState() {
    super.initState();
    _initBleState();
    _loadPrefs();
  }

  void _initBleState() {
    _isBluetoothConnected = _ble.isConnected;
    if (_ble.isConnected) {
      // FIX 1: use the real platform name captured by BleService at connect time.
      final name = _ble.connectedDeviceName ?? 'PRESSKO 1';
      _connectedDevice = ConnectedDevice(name: name, uuid: _deviceUuid);
    }

    _connectionSub = _ble.connectionStream.listen((connected) {
      if (!mounted) return;
      setState(() {
        _isBluetoothConnected = connected;
        if (connected) {
          final name = _ble.connectedDeviceName ?? 'PRESSKO 1';
          _connectedDevice = ConnectedDevice(name: name, uuid: _deviceUuid);
        } else {
          _connectedDevice = null;
        }
      });
    });
  }

  Future<void> _loadPrefs() async {
    final saved = await ConnectivityPrefs.load();
    if (!mounted) return;
    setState(() {
      _autoConnect = saved.autoConnectOnStartup;
      _autoReconnect = saved.autoReconnectIfDisconnected;
      _loading = false;
    });

    // FIX 2: push the persisted auto-reconnect pref into BleService on startup
    // so _scheduleRetry respects the user's last-known setting immediately.
    _ble.autoReconnectEnabled = _autoReconnect;

    if (_autoConnect && !_ble.isConnected) {
      _ble.startAutoConnect();
    }
  }

  Future<void> _savePrefs({
    required bool autoConnect,
    required bool autoReconnect,
  }) async {
    final prefs = ConnectivityPrefs(
      autoConnectOnStartup: autoConnect,
      autoReconnectIfDisconnected: autoReconnect,
    );
    await prefs.save();
    widget.onAutoConnectToggled?.call(autoConnect);
    widget.onAutoReconnectToggled?.call(autoReconnect);
  }

  Future<void> _onAutoConnectChanged(bool val) async {
    setState(() => _autoConnect = val);
    await _savePrefs(autoConnect: val, autoReconnect: _autoReconnect);

    if (val) {
      if (!_ble.isConnected) _ble.startAutoConnect();
    } else {
      // Both toggles OFF → stop retrying and disconnect.
      if (!_autoReconnect) {
        _ble.autoReconnectEnabled = false;
        if (_ble.isConnected) await _ble.disconnect();
      }
    }
  }

  Future<void> _onAutoReconnectChanged(bool val) async {
    setState(() => _autoReconnect = val);
    await _savePrefs(autoConnect: _autoConnect, autoReconnect: val);

    // FIX 2: tell BleService immediately so _scheduleRetry honours the toggle.
    _ble.autoReconnectEnabled = val;

    if (val && _autoConnect && !_ble.isConnected) {
      _ble.startAutoConnect();
    }
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    super.dispose();
  }

  static const Color _bgColor = Color(0xFF021E28);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bgColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final mq = MediaQuery.of(context);
    final double hPad = (mq.size.width * 0.05).clamp(14.0, 28.0);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 8),
              const Icon(Icons.chevron_left, color: Colors.white, size: 28),
              const SizedBox(width: 2),
              Text(
                'Back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _rfs(context, 16),
                ),
              ),
            ],
          ),
        ),
        leadingWidth: 80,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AppBar(horizontalPadding: hPad),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: hPad,
                  vertical: _rs(context, 12),
                ),
                child: Column(
                  children: [
                    _BluetoothStatusCard(isConnected: _isBluetoothConnected),
                    SizedBox(height: _rs(context, 12)),
                    _ToggleCard(
                      label: 'AUTO-CONNECT UPON START-UP',
                      value: _autoConnect,
                      onChanged: _onAutoConnectChanged,
                    ),
                    SizedBox(height: _rs(context, 12)),
                    _ToggleCard(
                      label: 'AUTO-RECONNECT IF DISCONNECTED',
                      value: _autoReconnect,
                      onChanged: _onAutoReconnectChanged,
                    ),
                    SizedBox(height: _rs(context, 12)),
                    if (_connectedDevice != null)
                      _ConnectedDeviceCard(device: _connectedDevice!),
                    if (_connectedDevice != null)
                      SizedBox(height: _rs(context, 12)),
                    _OtherDevicesCard(
                      onTap: widget.onOtherDevicesTapped ?? () {},
                    ),
                    SizedBox(height: mq.padding.bottom + _rs(context, 16)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── App Bar ──────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final double horizontalPadding;
  const _AppBar({required this.horizontalPadding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: _rs(context, 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(_rs(context, 6)),
            decoration: const BoxDecoration(
              color: Color(0xFF4DD9C0),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bluetooth,
              color: Colors.white,
              size: _rs(context, 20),
            ),
          ),
          SizedBox(width: _rs(context, 8)),
          Text(
            'Connectivity',
            style: TextStyle(
              color: Colors.white,
              fontSize: _rfs(context, 22),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bluetooth Status Card ────────────────────────────────────
class _BluetoothStatusCard extends StatelessWidget {
  final bool isConnected;
  const _BluetoothStatusCard({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      color: const Color(0xFFB0BEC5),
      fontSize: _rfs(context, 12),
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    );
    final statusStyle = TextStyle(
      color: isConnected ? const Color(0xFF4DD9C0) : Colors.redAccent,
      fontSize: _rfs(context, 12),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    return _BaseCard(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          Text('BLUETOOTH CONNECTIVITY STATUS:', style: labelStyle),
          Text(isConnected ? 'CONNECTED' : 'DISCONNECTED', style: statusStyle),
        ],
      ),
    );
  }
}

// ── Toggle Card ───────────────────────────────────────────────
class _ToggleCard extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: const Color(0xFFB0BEC5),
                fontSize: _rfs(context, 12),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          SizedBox(width: _rs(context, 12)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF4DD9C0),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFF37474F),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

// ── Connected Device Card ────────────────────────────────────
class _ConnectedDeviceCard extends StatelessWidget {
  final ConnectedDevice device;
  const _ConnectedDeviceCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      color: const Color(0xFFB0BEC5),
      fontSize: _rfs(context, 11),
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    );
    final valueStyle = TextStyle(
      color: const Color(0xFF4DD9C0),
      fontSize: _rfs(context, 13),
      fontWeight: FontWeight.w600,
    );

    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONNECTED DEVICE',
            style: TextStyle(
              color: const Color(0xFFB0BEC5),
              fontSize: _rfs(context, 11),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: _rs(context, 10)),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumn = constraints.maxWidth > 280;
              if (twoColumn) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _DeviceField(
                        label: 'DEVICE NAME:',
                        value: device.name,
                        labelStyle: labelStyle,
                        valueStyle: valueStyle,
                      ),
                    ),
                    SizedBox(width: _rs(context, 8)),
                    Expanded(
                      child: _DeviceField(
                        label: 'UUID:',
                        value: device.uuid,
                        labelStyle: labelStyle,
                        valueStyle: valueStyle.copyWith(
                          fontSize: _rfs(context, 12),
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DeviceField(
                      label: 'DEVICE NAME:',
                      value: device.name,
                      labelStyle: labelStyle,
                      valueStyle: valueStyle,
                    ),
                    SizedBox(height: _rs(context, 8)),
                    _DeviceField(
                      label: 'UUID:',
                      value: device.uuid,
                      labelStyle: labelStyle,
                      valueStyle: valueStyle.copyWith(
                        fontSize: _rfs(context, 12),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _DeviceField extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  const _DeviceField({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 4),
        Text(value, style: valueStyle, softWrap: true),
      ],
    );
  }
}

// ── Other Devices Card ────────────────────────────────────────
class _OtherDevicesCard extends StatelessWidget {
  final VoidCallback onTap;
  const _OtherDevicesCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/bluetooth_scan');
      },
      child: _BaseCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'CONNECT TO OTHER DEVICES',
                style: TextStyle(
                  color: const Color(0xFFB0BEC5),
                  fontSize: _rfs(context, 12),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: const Color(0xFF4DD9C0),
              size: _rs(context, 26),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Base Card ─────────────────────────────────────────
class _BaseCard extends StatelessWidget {
  final Widget child;
  const _BaseCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: _rs(context, 20),
        vertical: _rs(context, 18),
      ),
      decoration: BoxDecoration(
        color: const Color.fromARGB(186, 2, 60, 81),
        borderRadius: BorderRadius.circular(_rs(context, 14)),
      ),
      child: child,
    );
  }
}
