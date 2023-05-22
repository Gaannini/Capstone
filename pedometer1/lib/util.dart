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
  FETCHING_DATA,
  DATA_READY,
  NO_DATA,
  AUTHORIZED,
  AUTH_NOT_GRANTED,
  DATA_ADDED,
  DATA_DELETED,
  DATA_NOT_ADDED,
  DATA_NOT_DELETED,
  STEPS_READY,
}

class _HealthAppState extends State<HealthApp> {
  List<HealthDataPoint> _healthDataList = [];
  AppState _state = AppState.DATA_NOT_FETCHED;
  int _nofSteps = 0;
  double _calories = 0;

  // Define the types to get.
  // NOTE: These are only the ones supported on Androids new API Health Connect.
  // Both Android's Google Fit and iOS' HealthKit have more types that we support in the enum list [HealthDataType]
  // Add more - like AUDIOGRAM, HEADACHE_SEVERE etc. to try them.
  //static const types = dataTypesAndroid;
  // Or selected types
  static final types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];
  final permissions = types.map((e) => HealthDataAccess.READ_WRITE).toList();

  HealthFactory health = HealthFactory(useHealthConnectIfAvailable: true);

  Future authorize() async {
    // 필요한 걸음 수, 운동, 수면 또는 기타 데이터를 읽으려는 경우
    // ACTIVITY_RECOGNITION 권한, 먼저 권한을 요청해야 합니다.
    // 이것은 특별한 요청 인증 호출이 필요합니다.
    //
    // 거리 정보를 이용한 운동을 위해 위치 권한을 요청합니다.
    Permission.activityRecognition.request();
    await Permission.location.request();

    // Check if we have permission
    bool? hasPermissions =
        await health.hasPermissions(types, permissions: permissions);

    // hasPermissions = WRITE 액세스가 존재하는 경우 hasPermission이 공개할 수 없기 때문에 false입니다.
    // 따라서 WRITE로도 요청해야 합니다.
    hasPermissions = false;

    bool authorized = false;
    if (!hasPermissions) {
      // requesting access to the data types before reading them
      try {
        authorized =
            await health.requestAuthorization(types, permissions: permissions);
      } catch (error) {
        print("Exception in authorize: $error");
      }
    }

    setState(() => _state =
        (authorized) ? AppState.AUTHORIZED : AppState.AUTH_NOT_GRANTED);
  }

  /// Fetch data points from the health plugin and show them in the app.
  Future fetchData() async {
    setState(() => _state = AppState.FETCHING_DATA);

    // get data within the last 24 hours
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));
    final midnight = DateTime(now.year, now.month, now.day);

    // Clear old data points
    _healthDataList.clear();

    try {
      // fetch health data
      List<HealthDataPoint> healthData =
          await health.getHealthDataFromTypes(midnight, now, types);
      // save all the new data points (only the first 100)
      _healthDataList.addAll(
          (healthData.length < 100) ? healthData : healthData.sublist(0, 100));
    } catch (error) {
      print("Exception in getHealthDataFromTypes: $error");
    }

    // filter out duplicates
    _healthDataList = HealthFactory.removeDuplicates(_healthDataList);

    // print the results
    for (var x in _healthDataList) {
      print(x);
    }

    // update the UI to display the results
    setState(() {
      _state = _healthDataList.isEmpty ? AppState.NO_DATA : AppState.DATA_READY;
    });
  }

  /// Add some random health data.
  Future addData() async {
    final now = DateTime.now();
    final earlier = now.subtract(const Duration(minutes: 20));

    // Add data for supported types
    // NOTE: These are only the ones supported on Androids new API Health Connect.
    // Both Android's Google Fit and iOS' HealthKit have more types that we support in the enum list [HealthDataType]
    // Add more - like AUDIOGRAM, HEADACHE_SEVERE etc. to try them.
    bool success = true;
    success &= await health.writeHealthData(
        10, HealthDataType.BODY_FAT_PERCENTAGE, earlier, now);
    success &= await health.writeHealthData(
        1.925, HealthDataType.HEIGHT, earlier, now);
    success &=
        await health.writeHealthData(90, HealthDataType.WEIGHT, earlier, now);
    success &= await health.writeHealthData(
        90, HealthDataType.HEART_RATE, earlier, now);
    success &=
        await health.writeHealthData(100, HealthDataType.STEPS, earlier, now);
    success &= await health.writeHealthData(
        200, HealthDataType.ACTIVE_ENERGY_BURNED, earlier, now);
    success &= await health.writeHealthData(
        70, HealthDataType.HEART_RATE, earlier, now);
    success &= await health.writeHealthData(
        37, HealthDataType.BODY_TEMPERATURE, earlier, now);
    success &= await health.writeBloodOxygen(98, earlier, now, flowRate: 1.0);
    success &= await health.writeHealthData(
        105, HealthDataType.BLOOD_GLUCOSE, earlier, now);
    success &=
        await health.writeHealthData(1.8, HealthDataType.WATER, earlier, now);
    success &= await health.writeWorkoutData(
        HealthWorkoutActivityType.AMERICAN_FOOTBALL,
        now.subtract(const Duration(minutes: 15)),
        now,
        totalDistance: 2430,
        totalEnergyBurned: 400);
    success &= await health.writeBloodPressure(90, 80, earlier, now);

    // Store an Audiogram
    // Uncomment these on iOS - only available on iOS
    // const frequencies = [125.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0];
    // const leftEarSensitivities = [49.0, 54.0, 89.0, 52.0, 77.0, 35.0];
    // const rightEarSensitivities = [76.0, 66.0, 90.0, 22.0, 85.0, 44.5];

    // success &= await health.writeAudiogram(
    //   frequencies,
    //   leftEarSensitivities,
    //   rightEarSensitivities,
    //   now,
    //   now,
    //   metadata: {
    //     "HKExternalUUID": "uniqueID",
    //     "HKDeviceName": "bluetooth headphone",
    //   },
    // );

    setState(() {
      _state = success ? AppState.DATA_ADDED : AppState.DATA_NOT_ADDED;
    });
  }

  /// Delete some random health data.
  Future deleteData() async {
    final now = DateTime.now();
    final earlier = now.subtract(const Duration(hours: 24));

    bool success = true;
    for (HealthDataType type in types) {
      success &= await health.delete(type, earlier, now);
    }

    setState(() {
      _state = success ? AppState.DATA_DELETED : AppState.DATA_NOT_DELETED;
    });
  }

  /// Fetch steps from the health plugin and show them in the app.
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

      setState(() {
        _nofSteps = (steps == null) ? 0 : steps;
        _healthDataList = callist;
        _state = (steps == null) ? AppState.NO_DATA : AppState.STEPS_READY;
      });
    } else {
      print("Authorization not granted - error in authorization");
      setState(() => _state = AppState.DATA_NOT_FETCHED);
    }
  }

  Future revokeAccess() async {
    try {
      await health.revokePermissions();
    } catch (error) {
      print("Caught exception in revokeAccess: $error");
    }
  }

  Widget _contentFetchingData() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
            padding: const EdgeInsets.all(20),
            child: const CircularProgressIndicator(
              strokeWidth: 10,
            )),
        const Text('Fetching data...')
      ],
    );
  }

  Widget _contentDataReady() {
    return ListView.builder(
        itemCount: _healthDataList.length,
        itemBuilder: (_, index) {
          HealthDataPoint p = _healthDataList[index];
          if (p.value is AudiogramHealthValue) {
            return ListTile(
              title: Text("${p.typeString}: ${p.value}"),
              trailing: Text(p.unitString),
              subtitle: Text('${p.dateFrom} - ${p.dateTo}'),
            );
          }
          if (p.value is WorkoutHealthValue) {
            return ListTile(
              title: Text(
                  "${p.typeString}: ${(p.value as WorkoutHealthValue).totalEnergyBurned} ${(p.value as WorkoutHealthValue).totalEnergyBurnedUnit?.name}"),
              trailing: Text(
                  (p.value as WorkoutHealthValue).workoutActivityType.name),
              subtitle: Text('${p.dateFrom} - ${p.dateTo}'),
            );
          }
          return ListTile(
            title: Text("${p.typeString}: ${p.value}"),
            trailing: Text(p.unitString),
            subtitle: Text('${p.dateFrom} - ${p.dateTo}'),
          );
        });
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

  Widget _dataAdded() {
    return const Text('Data points inserted successfully!');
  }

  Widget _dataDeleted() {
    return const Text('Data points deleted successfully!');
  }

  Widget _stepsFetched() {
    for (var i = 0; i < _healthDataList.length; i++) {
      String a = _healthDataList[i].value.toString();
      _calories += double.parse(a);
    }
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
                      currentStep: (0.01 * _nofSteps).floor(),
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
                          '$_nofSteps',
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
                              Text(_calories.toString()),
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

  Widget _dataNotAdded() {
    return const Text('Failed to add data');
  }

  Widget _dataNotDeleted() {
    return const Text('Failed to delete data');
  }

  Widget _content() {
    if (_state == AppState.DATA_READY) {
      return _contentDataReady();
    } else if (_state == AppState.NO_DATA)
      return _contentNoData();
    else if (_state == AppState.FETCHING_DATA)
      return _contentFetchingData();
    else if (_state == AppState.AUTHORIZED)
      return _authorized();
    else if (_state == AppState.AUTH_NOT_GRANTED)
      return _authorizationNotGranted();
    else if (_state == AppState.DATA_ADDED)
      return _dataAdded();
    else if (_state == AppState.DATA_DELETED)
      return _dataDeleted();
    else if (_state == AppState.STEPS_READY)
      return _stepsFetched();
    else if (_state == AppState.DATA_NOT_ADDED)
      return _dataNotAdded();
    else if (_state == AppState.DATA_NOT_DELETED)
      return _dataNotDeleted();
    else
      return _contentNotFetched();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Health Example'),
        ),
        body: Container(
          child: Column(
            children: [
              Wrap(
                spacing: 10,
                children: [
                  TextButton(
                      onPressed: authorize,
                      style: const ButtonStyle(
                          backgroundColor:
                              MaterialStatePropertyAll(Colors.blue)),
                      child: const Text("Auth",
                          style: TextStyle(color: Colors.white))),
                  TextButton(
                      onPressed: fetchData,
                      style: const ButtonStyle(
                          backgroundColor:
                              MaterialStatePropertyAll(Colors.blue)),
                      child: const Text("Fetch Data",
                          style: TextStyle(color: Colors.white))),
                  TextButton(
                      onPressed: addData,
                      style: const ButtonStyle(
                          backgroundColor:
                              MaterialStatePropertyAll(Colors.blue)),
                      child: const Text("Add Data",
                          style: TextStyle(color: Colors.white))),
                  TextButton(
                      onPressed: deleteData,
                      style: const ButtonStyle(
                          backgroundColor:
                              MaterialStatePropertyAll(Colors.blue)),
                      child: const Text("Delete Data",
                          style: TextStyle(color: Colors.white))),
                  TextButton(
                      onPressed: fetchStepData,
                      style: const ButtonStyle(
                          backgroundColor:
                              MaterialStatePropertyAll(Colors.blue)),
                      child: const Text("Fetch Step Data",
                          style: TextStyle(color: Colors.white))),
                  TextButton(
                      onPressed: revokeAccess,
                      style: const ButtonStyle(
                          backgroundColor:
                              MaterialStatePropertyAll(Colors.blue)),
                      child: const Text("Revoke Access",
                          style: TextStyle(color: Colors.white))),
                ],
              ),
              const Divider(thickness: 3),
              Expanded(child: Center(child: _content()))
            ],
          ),
        ),
      ),
    );
  }
}
