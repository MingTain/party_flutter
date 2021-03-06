import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:zgadula/services/pictures.dart';

class CameraPreviewScreen extends StatefulWidget {
  @override
  CameraPreviewScreenState createState() => CameraPreviewScreenState();
}

class CameraPreviewScreenState extends State<CameraPreviewScreen>
    with TickerProviderStateMixin {
  static const pictureInterval = 15;

  CameraController controller;
  Directory pictureDir;
  Timer pictureTimer;
  int pictureTaken = 0;
  FileSystemEntity lastImage;

  AnimationController imageAnimationController;
  Animation<double> imageAnimation;
  double lastImageOpacity;
  Duration opacityAnimationDuration = Duration(milliseconds: 1000);

  @override
  void initState() {
    super.initState();
    initCamera();
    initAnimations();
  }

  initCamera() async {
    pictureDir = await PicturesService.getDirectory(context);
    var frontCamera = await PicturesService.getCamera();
    if (frontCamera == null) {
      return;
    }

    controller = CameraController(frontCamera, ResolutionPreset.high);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }

      startTimer();
      setState(() {});
    });
  }

  initAnimations() {
    imageAnimationController = AnimationController(
        vsync: this, duration: Duration(milliseconds: 1500));
    imageAnimation =
        Tween<double>(begin: 0, end: 1).animate(imageAnimationController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              setState(() {
                lastImageOpacity = 0;
                Future.delayed(opacityAnimationDuration).then((_) {
                  imageAnimationController.reset();
                });
              });
            }
          });
  }

  startTimer() {
    pictureTimer =
        Timer.periodic(const Duration(seconds: pictureInterval), savePicture);
  }

  stopTimer() {
    pictureTimer?.cancel();
  }

  savePicture(Timer timer) {
    controller.takePicture('${pictureDir.path}/$pictureTaken.png');

    Future.delayed(Duration(seconds: 1)).then((_) async {
      List<FileSystemEntity> files = await PicturesService.getFiles(context);
      setState(() {
        lastImageOpacity = 1;
        lastImage = files.last;
        imageAnimationController.forward();
      });
    });

    pictureTaken += 1;
  }

  @override
  void dispose() {
    controller?.dispose();
    imageAnimationController?.dispose();
    stopTimer();
    super.dispose();
  }

  Widget buildImageTaken() {
    return Positioned(
      right: 0,
      top: 0,
      child: AnimatedOpacity(
        opacity: lastImageOpacity,
        duration: opacityAnimationDuration,
        child: ScaleTransition(
          scale: imageAnimationController,
          child: Image.file(
            lastImage,
            fit: BoxFit.cover,
            width: 100,
            height: 100,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller.value.isInitialized) {
      return Container();
    }

    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Transform.rotate(
          angle: pi / 2,
          child: Stack(
            children: [
              CameraPreview(controller),
              lastImage != null ? buildImageTaken() : null,
            ].where((w) => w != null).toList(),
          ),
        ),
      ),
    );
  }
}
