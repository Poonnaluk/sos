import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sos/login.dart';

import 'camera/check_in.dart';
import 'camera/sos.dart';

void main(List<String> args) {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}

class ButtonPage extends StatefulWidget {
  const ButtonPage({Key? key}) : super(key: key);

  @override
  _ButtonPageState createState() => _ButtonPageState();
}

late List<CameraDescription> cameras;
late List<CameraDescription> _cameras;

void logError(String code, String? message) {
  if (message != null) {
    print('Error: $code\nError Message: $message');
  } else {
    print('Error: $code');
  }
}

Future<List<CameraDescription>> camara() async {
  // Fetch the available cameras before initializing the app.
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
  } on CameraException catch (e) {
    logError(e.code, e.description);
  }
  return cameras;
}

class _ButtonPageState extends State<ButtonPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
          child: Center(
        child: Row(
          // crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MaterialButton(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                      fit: BoxFit.fill,
                      image: AssetImage('assets/images/sos.png')),
                ),
              ),
              onPressed: () async {
                _cameras = await camara();
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SosVideoCamera(
                              cameras: _cameras,
                            )
                        // SosVideoCamera(cameras: _cameras)
                        ));
              },
            ),
            MaterialButton(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                      fit: BoxFit.fill,
                      image: AssetImage('assets/images/placeholder.png')),
                ),
              ),
              onPressed: () async {
                _cameras = await camara();
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CheckinPage(
                              cameras: _cameras,
                            )));
              },
            ),
          ],
        ),
      )),
    );
  }
}
