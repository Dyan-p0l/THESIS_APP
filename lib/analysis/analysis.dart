import 'package:flutter/material.dart';
import 'anim/result.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {

  int _capacitanceValue = 100;

  void updateCapacitanceValue(int newValue) {
    setState(() {
      _capacitanceValue = newValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0XFF012532),
      body: SafeArea(
        child: Column(
          children: [

            // 🔵 Top Section
            SizedBox(height: 10),

            Text(
              'Capacitance Reading',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 28,
                color: Color(0XFF40E0D0),
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$_capacitanceValue',
                  style: TextStyle(
                    fontFamily: 'RobotoMono',
                    fontWeight: FontWeight.bold,
                    fontSize: 96,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'pF',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                    color: Color(0XFF0FF7D8),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // 🔵 Bottom Section
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(width: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, 
                          color: Color.fromARGB(255, 134, 134, 134),
                          size: 30
                        ),
                        const SizedBox(width: 2),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('  Please ensure proper\ncontact with fish surface',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color.fromARGB(255, 134, 134, 134),
                              )
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 15),

                    SizedBox(
                      height: 450,
                      child: ResultScreen(),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 145,
                          height: 73,
                          child: TextButton(
                            onPressed: () {
                              
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Color(0XFF40E0D0),
                              backgroundColor: Color(0XFF012532),
                              padding: EdgeInsets.zero, 
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              "Save Result",
                              style: TextStyle(fontSize: 20), 
                            ),
                          ),
                        ),
                        const SizedBox(width: 30),
                        SizedBox(
                          width: 145,
                          height: 73,
                          child: TextButton(
                            onPressed: () {
                              
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Color(0XFF012532),
                              backgroundColor: Color(0XFF40E0D0),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              "New Test",
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ]
                    )

                  ],
                ),
              ),
            ),
          ],
        ),
      ), 
    );
  }
}