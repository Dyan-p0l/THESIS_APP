import 'package:flutter/material.dart';
import '../services/ble_service.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final BleService bleService = BleService();

  @override
  void initState() {
    super.initState();
    BleService().startAutoConnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF021E28),
      appBar: AppBar(
        backgroundColor: const Color(0xFF021E28),
        elevation: 0,
        title: const Text('Connectivity Status'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// 🔵 CONNECTION STATUS
            StreamBuilder<bool>(
              stream: bleService.connectionStream,
              builder: (context, snapshot) {
                final connected = snapshot.data ?? false;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.circle,
                      color: connected ? Colors.green : Colors.red,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      connected ? "Connected" : "Disconnected",
                      style: TextStyle(
                        color: connected ? Colors.green : Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 60),

            /// 🔵 LIVE CAPACITANCE DISPLAY
            StreamBuilder<double>(
              stream: bleService.capacitanceStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text(
                    "-- pF",
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }

                return Text(
                  "${snapshot.data!.toStringAsFixed(2)} pF",
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            const Text(
              "Live Capacitance Reading",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
