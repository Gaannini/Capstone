import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';

void main() {
  runApp(const WalkApp());
}

class WalkApp extends StatelessWidget {
  const WalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mountain Dew',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const WalkWidget(),
    );
  }
}

class WalkWidget extends StatefulWidget {
  const WalkWidget({super.key});

  @override
  State<WalkWidget> createState() => _WalkWidgetState();
}

class _WalkWidgetState extends State<WalkWidget> {
  //int walk = 0;
  //ShakeDetector? shakeDetector;
  late Timer timer;
  int totaltime = 0;
  bool isRunning = false;
  late Stream<StepCount> _stepCountStream;
  String _steps = '?';
  final int step = StepCount as int;

  void startpressed() {
    initPlatformState();
    timer = Timer.periodic(
      const Duration(seconds: 1),
      onTick,
    );
    setState(() {
      isRunning = true;
    });
  }

  void onStepCount(StepCount event) {
    print(event);
    setState(() {
      _steps = (step - event.steps) as String;
    });
  }

  void onStepCountError(error) {
    print('onStepCountError: $error');
    setState(() {
      _steps = 'Step Count not available';
    });
  }

  void initPlatformState() {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen(onStepCount).onError(onStepCountError);

    if (!mounted) return;
  }

  String format(int seconds) {
    var duration = Duration(seconds: seconds);
    return duration.toString().split(".").first;
  }

  void onTick(Timer timer) {
    setState(() {
      totaltime = totaltime + 1;
    });
  }

  void stoppressed() {
    if (mounted) {
      setState(() {
        isRunning = false;
        timer.cancel();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
              child: Container(
                child: Column(
                  children: <Widget>[
                    const SizedBox(
                      height: 100,
                    ),
                    CircularStepProgressIndicator(
                      totalSteps: 100,
                      currentStep: (0.01 * int.parse(_steps)).floor(),
                      stepSize: 30,
                      selectedColor: Colors.green[200],
                      unselectedColor: Colors.grey[200],
                      padding: 0,
                      width: 250,
                      height: 250,
                      selectedStepSize: 30,
                      roundedCap: (_, __) => false,
                      child: Center(
                        child: Text(
                          _steps,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 50,
                    ),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Column(
                            children: [
                              Icon(
                                Icons.timeline,
                                size: 60,
                                color: Color.fromARGB(255, 48, 158, 248),
                              ),
                              Text('거리'),
                              Text('3.92KM'),
                            ],
                          ),
                          const SizedBox(width: 50),
                          const Column(
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                size: 60,
                                color: Color.fromARGB(255, 236, 83, 18),
                              ),
                              Text('칼로리'),
                              Text('1,353KCAL'),
                            ],
                          ),
                          const SizedBox(width: 50),
                          Column(
                            children: [
                              const Icon(
                                Icons.timer,
                                size: 60,
                                color: Color.fromARGB(255, 255, 208, 66),
                              ),
                              const Text('시간'),
                              Text(
                                format(totaltime),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.all(Colors.green[100]),
                        ),
                        onPressed: isRunning ? stoppressed : startpressed,
                        child: Text(isRunning ? 'STOP' : 'START'),
                      ),
                    ),
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
