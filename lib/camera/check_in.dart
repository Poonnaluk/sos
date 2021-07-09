import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:sos/camera/utility/dialog.dart';
import 'package:video_player/video_player.dart';

// ignore: must_be_immutable
class CheckinPage extends StatefulWidget {
  List<CameraDescription> cameras;

  CheckinPage({Key? key, required this.cameras}) : super(key: key);
  @override
  _CheckinPageState createState() {
    return _CheckinPageState();
  }
}

/// Returns a suitable camera icon for [direction].
IconData getCameraLensIcon(CameraLensDirection direction) {
  switch (direction) {
    case CameraLensDirection.back:
      return Icons.camera_rear;
    case CameraLensDirection.front:
      return Icons.camera_front;
    case CameraLensDirection.external:
      return Icons.camera;
    default:
      throw ArgumentError('Unknown lens direction');
  }
}

void logError(String code, String? message) {
  if (message != null) {
    print('Error: $code\nError Message: $message');
  } else {
    print('Error: $code');
  }
}

class _CheckinPageState extends State<CheckinPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? controller;
  XFile? imageFile;
  XFile? videoFile;
  VideoPlayerController? videoController;
  VoidCallback? videoPlayerListener;
  bool enableAudio = true;
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _currentExposureOffset = 0.0;
  late AnimationController _flashModeControlRowAnimationController;
  late Animation<double> _flashModeControlRowAnimation;
  late AnimationController _exposureModeControlRowAnimationController;
  late Animation<double> _exposureModeControlRowAnimation;
  late AnimationController _focusModeControlRowAnimationController;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentScale = 1.0;
  double _baseScale = 1.0;

  // Counting pointers (number of user fingers on screen)
  int _pointers = 0;

  //location
  late double lat, long;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this);

    _flashModeControlRowAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _flashModeControlRowAnimation = CurvedAnimation(
      parent: _flashModeControlRowAnimationController,
      curve: Curves.easeInCubic,
    );
    _exposureModeControlRowAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _exposureModeControlRowAnimation = CurvedAnimation(
      parent: _exposureModeControlRowAnimationController,
      curve: Curves.easeInCubic,
    );
    _focusModeControlRowAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    controller = CameraController(widget.cameras[1], ResolutionPreset.medium);
    controller!.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraPreviewWidget();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    _flashModeControlRowAnimationController.dispose();
    _exposureModeControlRowAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<Null> findLatLong() async {
    LocationData? locationdata = await findlocation();
    setState(() {
      lat = locationdata!.latitude!;
      long = locationdata.longitude!;
      //post api ตรงนี้ได้
      print('latitude = $lat ,longitude = $long');
    });
  }

  Future<LocationData?> findlocation() async {
    Location location = Location();
    try {
      return await location.getLocation();
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Check in Camera'),
        backgroundColor: Colors.deepOrange[400],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              color: Colors.black87,
              child: Stack(
                alignment: Alignment.bottomCenter,
                fit: StackFit.loose,
                children: [_cameraPreviewWidget(), _modeControlRowWidget()],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(2.0),
            child: Container(
              color: Colors.black87,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  _cameraTogglesRowWidget(),
                ],
              ),
            ),
          ),
          _captureControlRowWidget(),
        ],
      ),
    );
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return const Text(
        'Tap a camera',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return Listener(
        onPointerDown: (_) => _pointers++,
        onPointerUp: (_) => _pointers--,
        child: CameraPreview(
          controller!,
          child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _handleScaleStart,
              onScaleUpdate: _handleScaleUpdate,
              onTapDown: (details) => onViewFinderTap(details, constraints),
            );
          }),
        ),
      );
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    // When there are not exactly two fingers on screen don't scale
    if (controller == null || _pointers != 2) {
      return;
    }

    _currentScale = (_baseScale * details.scale)
        .clamp(_minAvailableZoom, _maxAvailableZoom);

    await controller!.setZoomLevel(_currentScale);
  }

  /// Display the thumbnail of the captured image or video.
  Widget _thumbnailWidget() {
    final VideoPlayerController? localVideoController = videoController;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        localVideoController == null && imageFile == null
            ? Container()
            : SizedBox(
                child: (localVideoController == null)
                    ? Image.file(File(imageFile!.path))
                    : Container(
                        child: Center(
                          child: AspectRatio(
                              aspectRatio:
                                  // ignore: unnecessary_null_comparison
                                  localVideoController.value.size != null
                                      ? localVideoController.value.aspectRatio
                                      : 1.0,
                              child: VideoPlayer(localVideoController)),
                        ),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.pink)),
                      ),
                width: 64.0,
                height: 64.0,
              ),
      ],
    );
  }

  /// Display a bar with buttons to change the flash and exposure modes
  Widget _modeControlRowWidget() {
    return Column(
      children: [
        SizedBox(
          height: 4,
        ),
        Container(
          color: Colors.black87,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              IconButton(
                icon: Icon(Icons.flash_on),
                color: Colors.deepOrange[400],
                onPressed: controller != null ? onFlashModeButtonPressed : null,
              ),
              IconButton(
                icon: Icon(Icons.exposure),
                color: Colors.deepOrange[400],
                onPressed:
                    controller != null ? onExposureModeButtonPressed : null,
              ),
            ],
          ),
        ),
        _flashModeControlRowWidget(),
        _exposureModeControlRowWidget(),
      ],
    );
  }

  Widget _flashModeControlRowWidget() {
    return SizeTransition(
      sizeFactor: _flashModeControlRowAnimation,
      child: ClipRect(
        child: Container(
          color: Colors.black87,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            mainAxisSize: MainAxisSize.max,
            children: [
              IconButton(
                icon: Icon(Icons.flash_off),
                color: controller?.value.flashMode == FlashMode.off
                    ? Colors.orange
                    : Colors.blue,
                onPressed: controller != null
                    ? () => onSetFlashModeButtonPressed(FlashMode.off)
                    : null,
              ),
              IconButton(
                icon: Icon(Icons.flash_auto),
                color: controller?.value.flashMode == FlashMode.auto
                    ? Colors.orange
                    : Colors.blue,
                onPressed: controller != null
                    ? () => onSetFlashModeButtonPressed(FlashMode.auto)
                    : null,
              ),
              IconButton(
                icon: Icon(Icons.flash_on),
                color: controller?.value.flashMode == FlashMode.always
                    ? Colors.orange
                    : Colors.blue,
                onPressed: controller != null
                    ? () => onSetFlashModeButtonPressed(FlashMode.always)
                    : null,
              ),
              IconButton(
                icon: Icon(Icons.highlight),
                color: controller?.value.flashMode == FlashMode.torch
                    ? Colors.orange
                    : Colors.blue,
                onPressed: controller != null
                    ? () => onSetFlashModeButtonPressed(FlashMode.torch)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exposureModeControlRowWidget() {
    final ButtonStyle styleAuto = TextButton.styleFrom(
      primary: controller?.value.exposureMode == ExposureMode.auto
          ? Colors.orange
          : Colors.blue,
    );
    final ButtonStyle styleLocked = TextButton.styleFrom(
      primary: controller?.value.exposureMode == ExposureMode.locked
          ? Colors.orange
          : Colors.blue,
    );

    return SizeTransition(
      sizeFactor: _exposureModeControlRowAnimation,
      child: ClipRect(
        child: Container(
          color: Colors.black87,
          child: Column(
            children: [
              SizedBox(
                height: 15,
              ),
              Center(
                child: Text(
                  "Exposure Mode",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                mainAxisSize: MainAxisSize.max,
                children: [
                  TextButton(
                    child: Text('AUTO'),
                    style: styleAuto,
                    onPressed: controller != null
                        ? () =>
                            onSetExposureModeButtonPressed(ExposureMode.auto)
                        : null,
                    onLongPress: () {
                      if (controller != null) {
                        controller!.setExposurePoint(null);
                        showInSnackBar('Resetting exposure point');
                      }
                    },
                  ),
                  TextButton(
                    child: Text('LOCKED'),
                    style: styleLocked,
                    onPressed: controller != null
                        ? () =>
                            onSetExposureModeButtonPressed(ExposureMode.locked)
                        : null,
                  ),
                ],
              ),
              Center(
                child: Text(
                  "Exposure Offset",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    _minAvailableExposureOffset.toString(),
                    style: TextStyle(color: Colors.white),
                  ),
                  Slider(
                    value: _currentExposureOffset,
                    min: _minAvailableExposureOffset,
                    max: _maxAvailableExposureOffset,
                    label: _currentExposureOffset.toString(),
                    onChanged: _minAvailableExposureOffset ==
                            _maxAvailableExposureOffset
                        ? null
                        : setExposureOffset,
                  ),
                  Text(
                    _maxAvailableExposureOffset.toString(),
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Display the control bar with buttons to take pictures and record videos.
  Widget _captureControlRowWidget() {
    final VideoPlayerController? localVideoController = videoController;
    final CameraController? cameraController = controller;

    return Container(
      color: Colors.black87,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          _thumbnailWidget(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: MaterialButton(
                onPressed: cameraController != null &&
                        cameraController.value.isInitialized &&
                        !cameraController.value.isRecordingVideo
                    ? onTakePictureButtonPressed
                    : null,
                color: Colors.deepOrange[400],
                textColor: Colors.white,
                padding: EdgeInsets.all(25),
                shape: CircleBorder(),
                child: Center(
                    child: Text(
                  'Check in',
                  style: TextStyle(color: Colors.white),
                ))),
          ),
          localVideoController == null && imageFile == null
              ? Container()
              : SizedBox(
                  width: 64.0,
                  height: 64.0,
                  child: MaterialButton(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        image: DecorationImage(
                            fit: BoxFit.contain,
                            image: AssetImage('assets/images/check.png')),
                      ),
                    ),
                    onPressed: () async {
                      normalDialog(context, "แจ้งเตือน",
                          "คุณต้องการใช้รูปภาพนี้ Check in");
                    },
                  ),
                ),
        ],
      ),
    );
  }

  /// Display a row of toggle to select the camera (or a message if no camera is available).
  Widget _cameraTogglesRowWidget() {
    final List<Widget> toggles = <Widget>[];

    final onChanged = (CameraDescription? description) {
      if (description == null) {
        return;
      }

      onNewCameraSelected(description);
    };

    if (widget.cameras.isEmpty) {
      return const Text('No camera found');
    } else {
      for (CameraDescription cameraDescription in widget.cameras) {
        toggles.add(Theme(
          data: Theme.of(context).copyWith(
            unselectedWidgetColor: Colors.deepOrange[400],
          ),
          child: SizedBox(
            width: 90.0,
            child: RadioListTile<CameraDescription>(
              activeColor: Colors.deepOrange[400],
              title: Icon(getCameraLensIcon(cameraDescription.lensDirection),
                  color: Colors.deepOrange[400]),
              groupValue: controller?.description,
              value: cameraDescription,
              onChanged:
                  controller != null && controller!.value.isRecordingVideo
                      ? null
                      : onChanged,
            ),
          ),
        ));
      }
    }

    return Row(children: toggles);
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void showInSnackBar(String message) {
    // ignore: deprecated_member_use
    _scaffoldKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    final CameraController cameraController = controller!;

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    cameraController.setExposurePoint(offset);
    cameraController.setFocusPoint(offset);
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller!.dispose();
    }
    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: enableAudio,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    controller = cameraController;

    // If the controller is updated then update the UI.
    cameraController.addListener(() {
      if (mounted) setState(() {});
      if (cameraController.value.hasError) {
        showInSnackBar(
            'Camera error ${cameraController.value.errorDescription}');
      }
    });

    try {
      await cameraController.initialize();
      await Future.wait([
        cameraController
            .getMinExposureOffset()
            .then((value) => _minAvailableExposureOffset = value),
        cameraController
            .getMaxExposureOffset()
            .then((value) => _maxAvailableExposureOffset = value),
        cameraController
            .getMaxZoomLevel()
            .then((value) => _maxAvailableZoom = value),
        cameraController
            .getMinZoomLevel()
            .then((value) => _minAvailableZoom = value),
      ]);
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void onTakePictureButtonPressed() {
    findLatLong();
    takePicture().then((XFile? file) {
      if (mounted) {
        setState(() {
          imageFile = file;
          videoController?.dispose();
          videoController = null;
        });
        // if (file != null) showInSnackBar('Picture saved to ${file.path}');
      }
    });
  }

  void onFlashModeButtonPressed() {
    if (_flashModeControlRowAnimationController.value == 1) {
      _flashModeControlRowAnimationController.reverse();
    } else {
      _flashModeControlRowAnimationController.forward();
      _exposureModeControlRowAnimationController.reverse();
      _focusModeControlRowAnimationController.reverse();
    }
  }

  void onExposureModeButtonPressed() {
    if (_exposureModeControlRowAnimationController.value == 1) {
      _exposureModeControlRowAnimationController.reverse();
    } else {
      _exposureModeControlRowAnimationController.forward();
      _flashModeControlRowAnimationController.reverse();
      _focusModeControlRowAnimationController.reverse();
    }
  }

  // void onFocusModeButtonPressed() {
  //   if (_focusModeControlRowAnimationController.value == 1) {
  //     _focusModeControlRowAnimationController.reverse();
  //   } else {
  //     _focusModeControlRowAnimationController.forward();
  //     _flashModeControlRowAnimationController.reverse();
  //     _exposureModeControlRowAnimationController.reverse();
  //   }
  // }

  // void onAudioModeButtonPressed() {
  //   enableAudio = !enableAudio;
  //   if (controller != null) {
  //     onNewCameraSelected(controller!.description);
  //   }
  // }

  // void onCaptureOrientationLockButtonPressed() async {
  //   if (controller != null) {
  //     final CameraController cameraController = controller!;
  //     if (cameraController.value.isCaptureOrientationLocked) {
  //       await cameraController.unlockCaptureOrientation();
  //       showInSnackBar('Capture orientation unlocked');
  //     } else {
  //       await cameraController.lockCaptureOrientation();
  //       showInSnackBar(
  //           'Capture orientation locked to ${cameraController.value.lockedCaptureOrientation.toString().split('.').last}');
  //     }
  //   }
  // }

  void onSetFlashModeButtonPressed(FlashMode mode) {
    setFlashMode(mode).then((_) {
      if (mounted) setState(() {});
      showInSnackBar('Flash mode set to ${mode.toString().split('.').last}');
    });
  }

  void onSetExposureModeButtonPressed(ExposureMode mode) {
    setExposureMode(mode).then((_) {
      if (mounted) setState(() {});
      showInSnackBar('Exposure mode set to ${mode.toString().split('.').last}');
    });
  }

  // void onSetFocusModeButtonPressed(FocusMode mode) {
  //   setFocusMode(mode).then((_) {
  //     if (mounted) setState(() {});
  //     showInSnackBar('Focus mode set to ${mode.toString().split('.').last}');
  //   });
  // }

  // void onVideoRecordButtonPressed() {
  //   startVideoRecording().then((_) {
  //     if (mounted) setState(() {});
  //   });
  // }

  // void onStopButtonPressed() {
  //   stopVideoRecording().then((file) {
  //     if (mounted) setState(() {});
  //     if (file != null) {
  //       showInSnackBar('Video recorded to ${file.path}');
  //       videoFile = file;
  //       _startVideoPlayer();
  //     }
  //   });
  // }

  // void onPauseButtonPressed() {
  //   pauseVideoRecording().then((_) {
  //     if (mounted) setState(() {});
  //     showInSnackBar('Video recording paused');
  //   });
  // }

  // void onResumeButtonPressed() {
  //   resumeVideoRecording().then((_) {
  //     if (mounted) setState(() {});
  //     showInSnackBar('Video recording resumed');
  //   });
  // }

  // Future<void> startVideoRecording() async {
  //   final CameraController? cameraController = controller;

  //   if (cameraController == null || !cameraController.value.isInitialized) {
  //     showInSnackBar('Error: select a camera first.');
  //     return;
  //   }

  //   if (cameraController.value.isRecordingVideo) {
  //     // A recording is already started, do nothing.
  //     return;
  //   }

  //   try {
  //     await cameraController.startVideoRecording();
  //   } on CameraException catch (e) {
  //     _showCameraException(e);
  //     return;
  //   }
  // }

  // Future<XFile?> stopVideoRecording() async {
  //   final CameraController? cameraController = controller;

  //   if (cameraController == null || !cameraController.value.isRecordingVideo) {
  //     return null;
  //   }

  //   try {
  //     return cameraController.stopVideoRecording();
  //   } on CameraException catch (e) {
  //     _showCameraException(e);
  //     return null;
  //   }
  // }

  // Future<void> pauseVideoRecording() async {
  //   final CameraController? cameraController = controller;

  //   if (cameraController == null || !cameraController.value.isRecordingVideo) {
  //     return null;
  //   }

  //   try {
  //     await cameraController.pauseVideoRecording();
  //   } on CameraException catch (e) {
  //     _showCameraException(e);
  //     rethrow;
  //   }
  // }

  // Future<void> resumeVideoRecording() async {
  //   final CameraController? cameraController = controller;

  //   if (cameraController == null || !cameraController.value.isRecordingVideo) {
  //     return null;
  //   }

  //   try {
  //     await cameraController.resumeVideoRecording();
  //   } on CameraException catch (e) {
  //     _showCameraException(e);
  //     rethrow;
  //   }
  // }

  Future<void> setFlashMode(FlashMode mode) async {
    if (controller == null) {
      return;
    }

    try {
      await controller!.setFlashMode(mode);
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> setExposureMode(ExposureMode mode) async {
    if (controller == null) {
      return;
    }

    try {
      await controller!.setExposureMode(mode);
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> setExposureOffset(double offset) async {
    if (controller == null) {
      return;
    }

    setState(() {
      _currentExposureOffset = offset;
    });
    try {
      offset = await controller!.setExposureOffset(offset);
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  // Future<void> setFocusMode(FocusMode mode) async {
  //   if (controller == null) {
  //     return;
  //   }

  //   try {
  //     await controller!.setFocusMode(mode);
  //   } on CameraException catch (e) {
  //     _showCameraException(e);
  //     rethrow;
  //   }
  // }

  // Future<void> _startVideoPlayer() async {
  //   if (videoFile == null) {
  //     return;
  //   }

  //   final VideoPlayerController vController =
  //       VideoPlayerController.file(File(videoFile!.path));
  //   videoPlayerListener = () {
  //     // ignore: unnecessary_null_comparison
  //     if (videoController != null && videoController!.value.size != null) {
  //       // Refreshing the state to update video player with the correct ratio.
  //       if (mounted) setState(() {});
  //       videoController!.removeListener(videoPlayerListener!);
  //     }
  //   };
  //   vController.addListener(videoPlayerListener!);
  //   await vController.setLooping(true);
  //   await vController.initialize();
  //   await videoController?.dispose();
  //   if (mounted) {
  //     setState(() {
  //       imageFile = null;
  //       videoController = vController;
  //     });
  //   }
  //   await vController.play();
  // }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }

    if (cameraController.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
  }

  void _showCameraException(CameraException e) {
    logError(e.code, e.description);
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }
}
