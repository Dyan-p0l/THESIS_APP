import 'package:flutter/material.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF021E28),
      appBar: AppBar(
        title: const Text('Connectivity Status'),
      ),
      body: const Center(
        child: Text('Welcome to the Homepage!'),
      ),
    );
  }
}