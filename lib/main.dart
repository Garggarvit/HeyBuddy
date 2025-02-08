import 'package:flutter/material.dart';
import 'package:porcupine_flutter/porcupine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

void main() => runApp(HeyBuddyApp());

class HeyBuddyApp extends StatefulWidget {
  @override
  _HeyBuddyAppState createState() => _HeyBuddyAppState();
}

class _HeyBuddyAppState extends State<HeyBuddyApp> {
  Porcupine? _porcupine;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initPorcupine();
  }

  Future<void> _initPorcupine() async {
    if (await Permission.microphone.request().isGranted) {
      _porcupine = await Porcupine.fromKeywordPaths(
        'uMDruuGAhTybmn8RN9vFY2mIjFivG5zRuC7qMtjQWz5z/NZOuuLbJw==',
        ['"G:\heybuddy.ppn"'],
        (keywordIndex) {
          if (keywordIndex == 0) {
            _onWakeWordDetected();
          }
        },
      );
      _startListening();
    } else {
      print("Microphone permission denied");
    }
  }

  void _startListening() async {
    await _porcupine?.start();
    setState(() {
      _isListening = true;
    });
  }

  void _onWakeWordDetected() {
    print("Wake word detected!");
    // Here, trigger command processing or UI action
  }

  @override
  void dispose() {
    _porcupine?.stop();
    _porcupine?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("HeyBuddy")),
        body: Center(
          child: Text(_isListening ? "Listening for 'Hey Buddy'..." : "Initializing..."),
        ),
      ),
    );
  }
}
