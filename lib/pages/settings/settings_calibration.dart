import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/ble_service.dart';

class SettingsCalibrationScreen extends StatefulWidget {
  const SettingsCalibrationScreen({super.key});

  @override
  State<SettingsCalibrationScreen> createState() =>
      _SettingsCalibrationScreenState();
}

class _SettingsCalibrationScreenState extends State<SettingsCalibrationScreen> {
  final BleService _ble = BleService();

  double? _baselinePf;
  bool _isRecalibrating = false;

  StreamSubscription<double>? _calibSub;

  @override
  void initState() {
    super.initState();
    _baselinePf = _ble.latestCalibrationPf;

    _calibSub = _ble.calibrationStream.listen((value) {
      if (!mounted) return;
      setState(() {
        _baselinePf = value;
        _isRecalibrating = false;
      });
    });
  }

  @override
  void dispose() {
    _calibSub?.cancel();
    super.dispose();
  }

  Future<void> _onRecalibrate() async {
    if (!_ble.isConnected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ESP32 not connected')));
      return;
    }

    setState(() {
      _isRecalibrating = true;
      _baselinePf = null;
    });

    await _ble.sendRecalibrate();
  }

  String get _baselineDisplayValue {
    if (_isRecalibrating) return 'Recalibrating...';
    if (_baselinePf == null) return '—';
    return '${_baselinePf!.toStringAsFixed(3)} pF';
  }

  static const Color _bgColor = Color(0xFF021E28);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final double hPad = mq.size.width * 0.06;
    final double screenHeight = mq.size.height;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _CalibrationAppBar(),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: screenHeight * 0.02),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.tune, color: Color(0xFFD4C44A), size: 44),
                  SizedBox(width: 8),
                  Text(
                    'Calibration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.02),
              _DeviceAnimation(size: screenHeight * 0.22),
              SizedBox(height: screenHeight * 0.04),
              _BaselineValueCard(value: _baselineDisplayValue),
              SizedBox(height: screenHeight * 0.03),
              _InfoCard(),
              SizedBox(height: screenHeight * 0.06),
              _RecalibrateButton(
                isLoading: _isRecalibrating,
                onTap: _onRecalibrate,
              ),
              SizedBox(height: mq.padding.bottom + 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Custom AppBar ─────────────────────────────────────────────
class _CalibrationAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF021E28),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chevron_left, color: Colors.white, size: 28),
            Text('Back', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
      leadingWidth: 90,
    );
  }
}

// ── Device GIF Animation ──────────────────────────────────────
class _DeviceAnimation extends StatelessWidget {
  final double size;
  const _DeviceAnimation({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      child: Image.asset(
        'assets/images/onboardingpage/device_animation.gif',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.developer_board,
          size: size * 0.6,
          color: const Color(0xFF4DD9C0),
        ),
      ),
    );
  }
}

// ── Baseline Value Card ───────────────────────────────────────
class _BaselineValueCard extends StatelessWidget {
  final String value;
  const _BaselineValueCard({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF023C51),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'BASELINE CALIBRATION VALUE: ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF4DD9C0),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Card ─────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF023C51),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              textAlign: TextAlign.justify,
              text: const TextSpan(
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  height: 1.55,
                ),
                children: [
                  TextSpan(text: 'Calibration should be performed with '),
                  TextSpan(
                    text: 'no sample present on or near the IDE sensor',
                    style: TextStyle(color: Color(0xFF4DD9C0)),
                  ),
                  TextSpan(
                    text:
                        '. This step determines the baseline capacitance under ambient '
                        'conditions. Any external influence such as ',
                  ),
                  TextSpan(
                    text:
                        'fish contact, moisture, or nearby conductive objects',
                    style: TextStyle(color: Color(0xFF4DD9C0)),
                  ),
                  TextSpan(
                    text:
                        ' may introduce offsets and degrade the accuracy of subsequent '
                        'capacitance-based freshness assessments.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recalibrate Button ────────────────────────────────────────
class _RecalibrateButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _RecalibrateButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final double btnWidth = MediaQuery.of(context).size.width * 0.6;

    return SizedBox(
      width: btnWidth,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4DD9C0),
          disabledBackgroundColor: const Color(0xFF4DD9C0).withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'RECALIBRATE',
                style: TextStyle(
                  color: Color(0xFF0A1628),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
      ),
    );
  }
}
