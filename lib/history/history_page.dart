import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/reading.dart';
import 'data/mock_readings.dart';

enum SortType { date, sample, category }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  SortType selectedSort = SortType.date;

  List<Reading> get sortedReadings {
    List<Reading> list = [...mockReadings];

    switch (selectedSort) {
      case SortType.date:
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case SortType.sample:
        list.sort((a, b) => a.sampleLabel.compareTo(b.sampleLabel));
        break;
      case SortType.category:
        list.sort((a, b) => a.category.index.compareTo(b.category.index));
        break;
    }

    return list;
  }

  Map<String, List<Reading>> groupByDate(List<Reading> readings) {
    Map<String, List<Reading>> grouped = {};

    for (var reading in readings) {
      String dateKey = DateFormat('MMMM dd, yyyy').format(reading.timestamp);

      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(reading);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = groupByDate(sortedReadings);

    return Scaffold(
      backgroundColor: const Color(0xFF021E28),
      appBar: AppBar(
        backgroundColor: const Color(0xFF021E28),
        elevation: 0,
        title: const Text("Readings History"),
      ),
      body: Column(
        children: [
          _buildSortSelector(),
          Expanded(
            child: grouped.isEmpty
                ? const Center(
                    child: Text(
                      "No readings yet.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...entry.value
                              .map((reading) => _buildReadingCard(reading))
                              .toList(),
                          const SizedBox(height: 20),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortSelector() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: SortType.values.map((type) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: ChoiceChip(
              label: Text(type.name.toUpperCase()),
              selected: selectedSort == type,
              onSelected: (_) {
                setState(() => selectedSort = type);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReadingCard(Reading reading) {
    Color statusColor;
    IconData icon;

    switch (reading.category) {
      case FreshnessCategory.fresh:
        statusColor = Colors.tealAccent;
        icon = Icons.check_circle;
        break;
      case FreshnessCategory.moderate:
        statusColor = Colors.orangeAccent;
        icon = Icons.warning;
        break;
      case FreshnessCategory.spoiled:
        statusColor = Colors.redAccent;
        icon = Icons.error;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2F3C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${reading.capacitance.toStringAsFixed(0)} pF",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  reading.sampleLabel,
                  style: const TextStyle(color: Colors.cyanAccent),
                ),
                Text(
                  DateFormat('hh:mm a').format(reading.timestamp),
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(reading.id, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          Text(
            reading.category.name.toUpperCase(),
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
