import 'package:flutter/material.dart';

void showExistingSampleDialog(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;

  final List<String> existingSamples = [
    "Sample_00",
    "Sample_01",
    "Sample_02",
    "Sample_03",
    "Sample_04",
    "Sample_05",
    "Sample_06",
    "Sample_07",
    "Sample_08",
    "Sample_09",
    "Sample_10",
  ];

  const int scrollbarThreshold = 5;
  final bool showScrollbar = existingSamples.length > scrollbarThreshold;

  String? selectedSample = existingSamples.first;
  final ScrollController scrollController = ScrollController();

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(screenWidth * 0.06),
            ),
            insetPadding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.08,
              vertical: screenHeight * 0.1,
            ),
            child: Padding(
              padding: EdgeInsets.all(screenWidth * 0.06),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  Text(
                    "Choose Sample",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: screenWidth * 0.045,
                      color: const Color(0xFF012532),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.02),

                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: screenHeight * 0.4,
                    ),
                    child: Scrollbar(
                      controller: scrollController,
                      thumbVisibility: showScrollbar,
                      child: ListView.separated(
                        controller: scrollController,
                        shrinkWrap: true,
                        padding: EdgeInsets.only(right: screenWidth * 0.04),
                        itemCount: existingSamples.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: screenHeight * 0.012),
                        itemBuilder: (context, index) {
                          final sample = existingSamples[index];
                          final isSelected = selectedSample == sample;

                          return GestureDetector(
                            onTap: () {
                              setState(() => selectedSample = sample);
                            },
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                vertical: screenHeight * 0.02,
                                horizontal: screenWidth * 0.04,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEEEEE),
                                borderRadius:
                                    BorderRadius.circular(screenWidth * 0.03),
                                border: isSelected
                                    ? Border.all(
                                        color: const Color(0xFF40E0D0),
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: Text(
                                sample,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w500,
                                  fontSize: screenWidth * 0.04,
                                  color: const Color(0xFF012532),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.025),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF012532),
                        foregroundColor: const Color(0xFF40E0D0),
                        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(screenWidth * 0.03),
                        ),
                      ),
                      child: Text(
                        "SAVE",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: screenWidth * 0.05,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),

                ],
              ),
            ),
          );
        },
      );
    },
  );
}