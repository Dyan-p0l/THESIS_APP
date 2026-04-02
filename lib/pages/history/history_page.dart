import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../db/dbhelper.dart';
import '../../models/readings.dart';

enum SortType { date, sample, category }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  SortType selectedSort = SortType.date;
  List<Reading> readings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadReadings();
  }

  // fetch all readings from DB
  Future<void> loadReadings() async {
    final result = await DBhelper.instance.fetchAllReadings();
    setState(() {
      readings = result;
      isLoading = false;
    });
  }

  List<Reading> get sortedReadings {
    List<Reading> list = [...readings];

    switch (selectedSort) {
      case SortType.date:
        list.sort((a, b) => b.carriedOutAt.compareTo(a.carriedOutAt));
        break;
      case SortType.sample:
        // null sampleIds go to the end
        list.sort((a, b) {
          if (a.sampleId == null) return 1;
          if (b.sampleId == null) return -1;
          return a.sampleId!.compareTo(b.sampleId!);
        });
        break;
      case SortType.category:
        list.sort((a, b) {
          final catA = a.category ?? 'zzz'; // null categories go to end
          final catB = b.category ?? 'zzz';
          return catA.compareTo(catB);
        });
        break;
    }

    return list;
  }

  // group readings by date
  Map<String, List<Reading>> groupByDate(List<Reading> readings) {
    Map<String, List<Reading>> grouped = {};

    for (var reading in readings) {
      final dateTime = DateTime.parse(reading.carriedOutAt);
      final dateKey = DateFormat('MMMM dd, yyyy').format(dateTime);
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
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
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
                  : RefreshIndicator(
                      onRefresh: loadReadings, // pull to refresh
                      child: ListView(
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
                              ...entry.value.map((reading) =>
                                _buildReadingCard(reading, screenWidth, screenHeight)
                              ).toList(),
                              SizedBox(height: screenHeight * 0.015),
                            ],
                          );
                        }).toList(),
                      ),
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

    // determine color and icon based on category string
    Color statusColor;
    IconData icon;

    switch (reading.category) {
      case 'fresh':
        statusColor = Colors.tealAccent;
        icon = Icons.health_and_safety;
        break;
      case 'moderate':
        statusColor = Colors.orangeAccent;
        icon = Icons.health_and_safety;
        break;
      case 'spoiled':
        statusColor = Colors.redAccent;
        icon = Icons.report_problem_outlined;
        break;
      default:
        // category is null — not yet categorized
        statusColor = Colors.grey;
        icon = Icons.help_outline;
        break;
    }

    // parse carriedOutAt for time display
    final dateTime = DateTime.parse(reading.carriedOutAt);
    final timeDisplay = DateFormat('hh:mma').format(dateTime).toLowerCase();

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
                        reading.value.toStringAsFixed(0),  // ← value from DB
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
                    timeDisplay,                           // ← time from carriedOutAt
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
                    reading.sampleId != null
                      ? 'Sample #${reading.sampleId}'  // ← show sample id for now
                      : 'No sample',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.003),
                  Text(
                    'ID: ${reading.id ?? '-'}',          // ← reading id from DB
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
                    reading.category?.toUpperCase() ?? 'N/A',  // ← nullable category
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