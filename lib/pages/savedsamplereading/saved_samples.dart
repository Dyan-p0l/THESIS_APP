import 'package:flutter/material.dart';
import '../../db/dbhelper.dart';
import '../../models/samples.dart';

class SavedSamplesScreen extends StatefulWidget {
  const SavedSamplesScreen({super.key});

  @override
  State<SavedSamplesScreen> createState() => _SavedSamplesScreenState();
}

class _SavedSamplesScreenState extends State<SavedSamplesScreen> {
  List<Sample> _samples = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSamples();
  }

  Future<void> _loadSamples() async {
    final samples = await DBhelper.instance.fetchAllSamples();
    if (mounted) {
      setState(() {
        _samples = samples;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF021E28);
    const accent = Color(0xFF56DFB1);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.055,
            vertical: screenHeight * 0.022,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: screenHeight * 0.02),

              // ── HEADER ──
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.03,
                        vertical: screenHeight * 0.008,
                      ),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(screenWidth * 0.02),
                      ),
                      child: Text(
                        "«",
                        style: TextStyle(
                          fontFamily: "Inter",
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF021E28),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Text(
                    "Saved Readings",
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontSize: screenWidth * 0.058,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              SizedBox(height: screenHeight * 0.035),

              // ── SAMPLE LIST ──
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: accent,
                        ),
                      )
                    : _samples.isEmpty
                        ? Center(
                            child: Text(
                              "No saved samples yet.",
                              style: TextStyle(
                                fontFamily: "Inter",
                                fontSize: screenWidth * 0.042,
                                color: Colors.white54,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _samples.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(height: screenHeight * 0.018),
                            itemBuilder: (context, index) {
                              final sample = _samples[index];
                              return SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/sample_readings',
                                      arguments: {
                                        'sampleId': sample.id,
                                        'sampleLabel': sample.label, 
                                      },
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0D2E3D),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: EdgeInsets.symmetric(
                                      vertical: screenHeight * 0.022,
                                      horizontal: screenWidth * 0.05,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        screenWidth * 0.03,
                                      ),
                                      side: BorderSide(
                                        color: Colors.white.withOpacity(0.08),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      sample.label,
                                      style: TextStyle(
                                        fontFamily: "Inter",
                                        fontSize: screenWidth * 0.042,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),

              SizedBox(height: screenHeight * 0.025),

              // ── GENERATE CSV ──
              SizedBox(
                width: screenWidth * 0.70,
                child: ElevatedButton(
                  onPressed: _samples.isEmpty ? null : () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            screenWidth * 0.04,
                          ),
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "CSV file successfully generated.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: "Inter",
                                fontSize: screenWidth * 0.038,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.008),
                            Text(
                              "/storage/emulated/0/Download/",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: "Inter",
                                fontSize: screenWidth * 0.032,
                                color: Colors.black54,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.018),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: const Color(0xFF021E28),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    screenWidth * 0.05,
                                  ),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.08,
                                  vertical: screenHeight * 0.012,
                                ),
                              ),
                              child: Text(
                                "OK",
                                style: TextStyle(
                                  fontFamily: "Inter",
                                  fontWeight: FontWeight.w700,
                                  fontSize: screenWidth * 0.038,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: const Color(0xFF021E28),
                    disabledBackgroundColor: accent.withOpacity(0.4),
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.02,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.04),
                    ),
                  ),
                  child: Text(
                    "GENERATE CSV",
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontSize: screenWidth * 0.043,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.012),
            ],
          ),
        ),
      ),
    );
  }
}