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
    const Color darkTeal = Color(0xFF03313E);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leadingWidth: screenWidth * 0.175,
        leading: Padding(
          padding: EdgeInsets.only(
            left: screenWidth * 0.04,
            top: screenHeight * 0.01,
            bottom: screenHeight * 0.01,
          ),
          child: GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/homepage');
            },
            child: Container(
              decoration: BoxDecoration(
                color: darkTeal,
                borderRadius: BorderRadius.circular(screenWidth * 0.05),
              ),
              child: Icon(
                Icons.keyboard_double_arrow_left,
                color: Colors.cyanAccent,
                size: screenWidth * 0.07,
              ),
            ),
          ),
        ),
        title: Text(
          "Readings History",
          style: TextStyle(
            color: darkTeal,
            fontWeight: FontWeight.w800,
            fontSize: screenWidth * 0.065,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSortSelector(screenWidth),
          Expanded(
            child: grouped.isEmpty
                ? const Center(
                    child: Text(
                      "No readings yet.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.04,
                      vertical: screenHeight * 0.01,
                    ),
                    children: grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: screenHeight * 0.01,
                            ),
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                color: const Color(0xFF1E293B),
                                fontSize: screenWidth * 0.045,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ...entry.value
                              .map((reading) =>
                                  _buildReadingCard(reading, screenWidth, screenHeight))
                              .toList(),
                          SizedBox(height: screenHeight * 0.015),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortSelector(double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenWidth * 0.02,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Sort by:",
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF03313E),
            ),
          ),
          SizedBox(height: screenWidth * 0.02),
          Row(
            children: SortType.values.map((type) {
              final isSelected = selectedSort == type;
              return Padding(
                padding: EdgeInsets.only(right: screenWidth * 0.03),
                child: ChoiceChip(
                  label: Text(type.name.toUpperCase()),
                  selected: isSelected,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.03,
                  ),
                  backgroundColor: const Color(0xFFD1D5DB),
                  selectedColor: const Color(0xFF03313E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(screenWidth * 0.05),
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

  Widget _buildReadingCard(Reading reading, double screenWidth, double screenHeight) {
    Color statusColor;
    IconData icon;

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
      margin: EdgeInsets.only(bottom: screenHeight * 0.012),
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.015,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF042F3C),
        borderRadius: BorderRadius.circular(screenWidth * 0.025),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Icon(icon, color: statusColor, size: screenWidth * 0.095),
            SizedBox(width: screenWidth * 0.04),

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
                        style: TextStyle(
                          fontSize: screenWidth * 0.065,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "pF",
                        style: TextStyle(
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    DateFormat('hh:mma').format(reading.timestamp).toLowerCase(),
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: screenWidth * 0.03,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    reading.sampleLabel,
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.003),
                  Text(
                    reading.id,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.028,
                    ),
                  ),
                ],
              ),
            ),

            const VerticalDivider(
              color: Colors.white70,
              thickness: 1,
              width: 24,
            ),

            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "CATEGORY:",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.025,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.003),
                  Text(
                    reading.category.name.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: screenWidth * 0.033,
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