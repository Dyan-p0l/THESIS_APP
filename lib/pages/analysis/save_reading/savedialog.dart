import 'package:flutter/material.dart';
import 'showexistingsamples.dart';

void showSaveDialog(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  final TextEditingController labelController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.06),
        ),
        insetPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.08,
          vertical: screenHeight * 0.1,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(screenWidth * 0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              Container(
                width: double.infinity,
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.circular(screenWidth * 0.04),
                ),
                child: Column(
                  children: [
                    Text(
                      "SAVE AS\nNEW SAMPLE",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: screenWidth * 0.04,
                        color: const Color(0xFF012532),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    TextField(
                      controller: labelController,
                      decoration: InputDecoration(
                        hintText: "Enter Sample Label",
                        hintStyle: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: screenWidth * 0.04,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.04,
                          vertical: screenHeight * 0.018,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(screenWidth * 0.03),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
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

              SizedBox(height: screenHeight * 0.025),

              Text(
                "OR",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: screenWidth * 0.045,
                  color: Colors.black87,
                ),
              ),

              SizedBox(height: screenHeight * 0.025),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    showExistingSampleDialog(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF40E0D0),
                    foregroundColor: const Color(0xFF012532),
                    padding: EdgeInsets.symmetric(vertical: screenHeight * 0.022),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.04),
                    ),
                  ),
                  child: Text(
                    "SAVE TO EXISTING\nSAMPLE",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: screenWidth * 0.05,
                      height: 1.3,
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
}