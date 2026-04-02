import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:thesis_app/pages/history/models/reading.dart';
import 'package:thesis_app/pages/history/data/mock_readings.dart';

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
    const Color darkTeal = Color(0xFF03313E);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
          child: GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/homepage');
            },
            child: Container(
              decoration: BoxDecoration(
                color: darkTeal,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.keyboard_double_arrow_left,
                color: Colors.cyanAccent,
                size: 28,
              ),
            ),
          ),
        ),
        title: Text(
          "Readings History",
          style: TextStyle(
            color: darkTeal,
            fontWeight: FontWeight.w800,
            fontSize: 26,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    children: grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                color: Color(0xFF1E293B), // Dark text for date
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ...entry.value.map(
                            (reading) => _buildReadingCard(reading),
                          ),
                          const SizedBox(height: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Sort by:",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF03313E),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: SortType.values.map((type) {
              final isSelected = selectedSort == type;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ChoiceChip(
                  label: Text(type.name.toUpperCase()),
                  selected: isSelected,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  backgroundColor: const Color(
                    0xFFD1D5DB,
                  ), // Light grey for unselected
                  selectedColor: const Color(
                    0xFF03313E,
                  ), // Dark teal for selected
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide.none,
                  ),
                  onSelected: (_) {
                    setState(() => selectedSort = type);
                  },
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingCard(Reading reading) {
    Color statusColor;
    IconData icon;

    // Matching the icons and colors as closely as possible to the mockup
    switch (reading.category) {
      case FreshnessCategory.fresh:
        statusColor = Colors.tealAccent;
        icon = Icons.health_and_safety;
        break;
      case FreshnessCategory.moderate:
        statusColor = Colors.orangeAccent;
        icon = Icons.health_and_safety;
        break;
      case FreshnessCategory.spoiled:
        statusColor = Colors.redAccent;
        icon = Icons.report_problem_outlined;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF042F3C), // Deep navy/teal card background
        borderRadius: BorderRadius.circular(10),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // 1. Icon Section
            Icon(icon, color: statusColor, size: 38),
            const SizedBox(width: 16),

            // 2. Capacitance & Time Section
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        reading.capacitance.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        "pF",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    DateFormat(
                      'hh:mma',
                    ).format(reading.timestamp).toLowerCase(),
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // 3. Sample Label & ID Section
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    reading.sampleLabel,
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reading.id,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),

            // 4. Vertical Divider
            const VerticalDivider(
              color: Colors.white70,
              thickness: 1,
              width: 24,
            ),

            // 5. Category Status Section
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "CATEGORY:",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reading.category.name.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
