// ignore_for_file: non_constant_identifier_names

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';

void main() => runApp(const HealthApp());

class HealthApp extends StatefulWidget {
  const HealthApp({super.key});

  @override
  _HealthAppState createState() => _HealthAppState();
}

enum AppState {
  DATA_NOT_FETCHED,
  NO_DATA,
  AUTHORIZED,
  AUTH_NOT_GRANTED,
  STEPS_READY,
}

class _HealthAppState extends State<HealthApp> {
  List<HealthDataPoint> _healthDataList = [];
  AppState _state = AppState.DATA_NOT_FETCHED;
  int start_steps = 0;
  int now_steps = 0;
  double _calories = 0;
  double start_calories = 0;
  double now_calories = 0;
  Timer? _timer;

  static final types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];
  final permissions = types.map((e) => HealthDataAccess.READ_WRITE).toList();

  HealthFactory health = HealthFactory(useHealthConnectIfAvailable: true);

  Future authorize() async {
    Permission.activityRecognition.request();
    await Permission.location.request();
    bool? hasPermissions =
        await health.hasPermissions(types, permissions: permissions);
    hasPermissions = false;

    bool authorized = false;
    if (!hasPermissions) {
      try {
        authorized =
            await health.requestAuthorization(types, permissions: permissions);
      } catch (error) {
        print("Exception in authorize: $error");
      }
    }

    setState(() {
      _state = (authorized) ? AppState.STEPS_READY : AppState.AUTH_NOT_GRANTED;
      fetchStepData();
    });
  }

  Future fetchStepData() async {
    List<HealthDataType> cal = [
      HealthDataType.ACTIVE_ENERGY_BURNED,
    ];
    List<HealthDataPoint> callist = [];
    int? steps;
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    bool requestedstep =
        await health.requestAuthorization([HealthDataType.STEPS]);
    bool requestedcal = await health
        .requestAuthorization([HealthDataType.ACTIVE_ENERGY_BURNED]);

    if (requestedstep && requestedcal) {
      try {
        steps = await health.getTotalStepsInInterval(midnight, now);
        callist = await health.getHealthDataFromTypes(midnight, now, cal);
      } catch (error) {
        print("Caught exception in getTotalStepsInInterval: $error");
      }

      final start_steps = (steps == null) ? 0 : steps;
      _healthDataList = callist;

      for (var i = 0; i < _healthDataList.length; i++) {
        String a = _healthDataList[i].value.toString();
        _calories += double.parse(a);
      }
      final start_calories = _calories;
      _calories = 0;

      _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        setState(() {
          now_steps = (steps == null) ? 0 : steps - start_steps;
          for (var i = 0; i < _healthDataList.length; i++) {
            String a = _healthDataList[i].value.toString();
            _calories += double.parse(a);
          }
          now_calories = _calories - start_calories;

          _state = (steps == null) ? AppState.NO_DATA : AppState.STEPS_READY;
        });
      });
    } else {
      print("Authorization not granted - error in authorization");
      setState(() => _state = AppState.DATA_NOT_FETCHED);
    }
  }

  Widget _contentNoData() {
    return const Text('No Data to show');
  }

  Widget _contentNotFetched() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Press the download button to fetch data.'),
        Text('Press the plus button to insert some random data.'),
        Text('Press the walking button to get total step count.'),
      ],
    );
  }

  Widget _authorized() {
    return const Text('Authorization granted!');
  }

  Widget _authorizationNotGranted() {
    return const Text('Authorization not given. '
        'For Android please check your OAUTH2 client ID is correct in Google Developer Console. '
        'For iOS check your permissions in Apple Health.');
  }

  Widget _stepsFetched() {
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
                      height: 50,
                    ),
                    CircularStepProgressIndicator(
                      totalSteps: 100,
                      currentStep: (0.01 * now_steps).floor(),
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
                          '$now_steps',
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
                          Column(
                            children: [
                              const Icon(
                                Icons.local_fire_department,
                                size: 60,
                                color: Color.fromARGB(255, 236, 83, 18),
                              ),
                              const Text('칼로리'),
                              Text('$now_calories'),
                            ],
                          ),
                          const SizedBox(width: 50),
                          const Column(
                            children: [
                              Icon(
                                Icons.timer,
                                size: 60,
                                color: Color.fromARGB(255, 255, 208, 66),
                              ),
                              Text('시간'),
                              Text(''),
                            ],
                          ),
                        ],
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

  Widget _content() {
    if (_state == AppState.NO_DATA) {
      return _contentNoData();
    } else if (_state == AppState.AUTHORIZED)
      return _authorized();
    else if (_state == AppState.AUTH_NOT_GRANTED)
      return _authorizationNotGranted();
    else if (_state == AppState.STEPS_READY)
      return _stepsFetched();
    else
      return _contentNotFetched();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const Divider(thickness: 3),
            Expanded(child: Center(child: _stepsFetched())),
            TextButton(
              onPressed: authorize,
              child: const Text("시작"),
            ),
          ],
        ),
      ),
    );
  }
}
