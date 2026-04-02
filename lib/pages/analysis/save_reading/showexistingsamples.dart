import 'package:flutter/material.dart';
import '../../../db/dbhelper.dart';
import '../../../models/samples.dart';

void showExistingSampleDialog(
  BuildContext context, {
  required int readingId,
  required double value,
  required String carriedOutAt,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  final ScrollController scrollController = ScrollController();
  
  List<Sample> samples = [];
  Sample? selectedSample;
  bool isLoading = true;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {

          // load samples from DB once
          Future<void> loadSamples() async {
            final result = await DBhelper.instance.fetchAllSamples();
            setState(() {
              samples = result;
              selectedSample = result.isNotEmpty ? result.first : null;
              isLoading = false;
            });
          }

          if (isLoading) loadSamples();

          final bool showScrollbar = samples.length > 5;

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

                  // show loading, empty state, or list
                  isLoading
                    ? const CircularProgressIndicator()
                    : samples.isEmpty
                      ? Text(
                          "No samples found.\nSave as a new sample first.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: screenWidth * 0.038,
                            color: Colors.grey,
                          ),
                        )
                      : ConstrainedBox(
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
                              itemCount: samples.length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: screenHeight * 0.012),
                              itemBuilder: (context, index) {
                                final sample = samples[index];
                                final isSelected = selectedSample?.id == sample.id;

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
                                      borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                      border: isSelected
                                          ? Border.all(
                                              color: const Color(0xFF40E0D0),
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                    child: Text(
                                      sample.label,   // ← from DB not hardcoded
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
                      // disable button if no sample selected or still loading
                      onPressed: (isLoading || selectedSample == null)
                        ? null
                        : () async {
                            // update existing reading — link to selected sample
                            await DBhelper.instance.saveReadingToSample(
                              readingId,
                              selectedSample!.id!,
                            );

                            Navigator.pop(context); // close existing sample dialog
                            Navigator.pop(context); // close save dialog

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Saved to ${selectedSample!.label}')),
                            );
                          },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF012532),
                        foregroundColor: const Color(0xFF40E0D0),
                        disabledBackgroundColor: Colors.grey.shade300,
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