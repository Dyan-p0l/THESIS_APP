import 'package:flutter/material.dart';

// ============================================================
// CONNECTIVITY DATA MODEL
// Replace this with real data from your service/BLoC/Provider
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

  const ConnectedDevice({
    required this.name,
    required this.uuid,
  });
}

// ============================================================
// DUMMY DATA — swap this out when your service is ready
// ============================================================
const ConnectivityData kDummyConnectivityData = ConnectivityData(
  isBluetoothConnected: true,
  autoConnectOnStartup: true,
  autoReconnectIfDisconnected: true,
  connectedDevice: ConnectedDevice(
    name: 'FDC1004',
    uuid: '6a6e2d3b-2c5f-4d3a-9b41-2c8a9c0a9b10',
  ),
  otherDevicesCount: 0,
);

// ============================================================
// RESPONSIVE HELPERS
// ============================================================

/// Returns a font size scaled to screen width.
/// [base] is the size at the reference width of 390 px (iPhone 14).
double _rfs(BuildContext context, double base) {
  final width = MediaQuery.of(context).size.width;
  // Clamp between 0.8× and 1.2× of base to avoid extremes.
  final scale = (width / 390.0).clamp(0.8, 1.2);
  return base * scale;
}

/// Returns a spacing/dimension value scaled to screen width.
double _rs(BuildContext context, double base) {
  final width = MediaQuery.of(context).size.width;
  final scale = (width / 390.0).clamp(0.75, 1.3);
  return base * scale;
}

// ============================================================
// CONNECTIVITY SCREEN
// ============================================================
class SettingsConnectivityScreen extends StatefulWidget {
  final ConnectivityData? data;
  final ValueChanged<bool>? onAutoConnectToggled;
  final ValueChanged<bool>? onAutoReconnectToggled;
  final VoidCallback? onOtherDevicesTapped;

  const SettingsConnectivityScreen({
    super.key,
    this.data,
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
  late bool _autoConnect;
  late bool _autoReconnect;

  ConnectivityData get _data => widget.data ?? kDummyConnectivityData;

  @override
  void initState() {
    super.initState();
    _autoConnect = _data.autoConnectOnStartup;
    _autoReconnect = _data.autoReconnectIfDisconnected;
  }

  @override
  void didUpdateWidget(SettingsConnectivityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data && widget.data != null) {
      _autoConnect = widget.data!.autoConnectOnStartup;
      _autoReconnect = widget.data!.autoReconnectIfDisconnected;
    }
  }

  static const Color _bgColor = Color(0xFF021E28);
  static const Color _accentCyan = Color(0xFF4DD9C0);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Horizontal padding: 5% of width, clamped between 14–28 px.
    final double hPad = (mq.size.width * 0.05).clamp(14.0, 28.0);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
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
                    _BluetoothStatusCard(
                        isConnected: _data.isBluetoothConnected),
                    SizedBox(height: _rs(context, 12)),
                    _ToggleCard(
                      label: 'AUTO-CONNECT UPON START-UP',
                      value: _autoConnect,
                      onChanged: (val) {
                        setState(() => _autoConnect = val);
                        widget.onAutoConnectToggled?.call(val);
                      },
                    ),
                    SizedBox(height: _rs(context, 12)),
                    _ToggleCard(
                      label: 'AUTO-RECONNECT IF DISCONNECTED',
                      value: _autoReconnect,
                      onChanged: (val) {
                        setState(() => _autoReconnect = val);
                        widget.onAutoReconnectToggled?.call(val);
                      },
                    ),
                    SizedBox(height: _rs(context, 12)),
                    if (_data.connectedDevice != null)
                      _ConnectedDeviceCard(device: _data.connectedDevice!),
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
    // Label style shared between both text spans
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
        // Wrap onto the next line on very narrow screens.
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          Text('BLUETOOTH CONNECTIVITY STATUS:', style: labelStyle),
          Text(
            isConnected ? 'CONNECTED' : 'DISCONNECTED',
            style: statusStyle,
          ),
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
          // On very small screens this wraps to two rows gracefully.
          LayoutBuilder(builder: (context, constraints) {
            // If there's enough room keep side-by-side, else stack vertically.
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
          }),
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