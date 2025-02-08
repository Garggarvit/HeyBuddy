import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HeyBuddyApp());
}

class HeyBuddyApp extends StatefulWidget {
  const HeyBuddyApp({Key? key}) : super(key: key);

  @override
  _HeyBuddyAppState createState() => _HeyBuddyAppState();
}

class _HeyBuddyAppState extends State<HeyBuddyApp> {
  final Logger _logger = Logger();
  PorcupineManager? _porcupineManager;
  bool _isListening = false;
  bool _isInitialized = false;
  String _statusMessage = "Initializing...";

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _requestPermissions();
      await _initPorcupine();
      setState(() {
        _isInitialized = true;
        _statusMessage = "Ready to listen!";
      });
    } catch (e, stackTrace) {
      _logger.e("FATAL ERROR DURING INIT",
          error: e, stackTrace: stackTrace, time: DateTime.now());
      if (mounted) {
        setState(() {
          _statusMessage = "Critical Error:\n${e.toString().split(":").first}";
        });
      }
      await Future.delayed(const Duration(seconds: 2));
      SystemNavigator.pop(); // Exit gracefully
    }
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      _logger.i("Microphone permission already granted");
    } else {
      final newStatus = await Permission.microphone.request();
      if (newStatus.isGranted) {
        _logger.i("Microphone permission granted");
      } else if (newStatus.isPermanentlyDenied) {
        _logger.w("Microphone permission permanently denied");
        openAppSettings();
        throw Exception("Mic permission required. Enable it in settings.");
      } else {
        _logger.w("Microphone permission denied");
        throw Exception("Mic permission required for app functionality.");
      }
    }
  }

  Future<void> _initPorcupine() async {
    try {
      _logger.i("Starting Porcupine initialization");

      // Verify that required assets are listed in the asset manifest.
      final manifestString = await rootBundle.loadString('AssetManifest.json');
      final manifest = json.decode(manifestString) as Map<String, dynamic>;
      if (!manifest.containsKey('assets/heybuddy.ppn') ||
          !manifest.containsKey('assets/porcupine_params.pv')) {
        throw Exception("Missing Porcupine assets in bundle");
      }

      // Load assets to device storage.
      final ppnPath = await _loadAsset('heybuddy.ppn');
      final modelPath = await _loadAsset('porcupine_params.pv');

      _logger.i("Creating PorcupineManager instance");
      _porcupineManager = await PorcupineManager.fromKeywordPaths(
        'uMDruuGAhTybmn8RN9vFY2mIjFivG5zRuC7qMtjQWz5z/NZOuuLbJw==',
        [ppnPath],
        _onWakeWordDetected,
        modelPath: modelPath,
      );

      _logger.i("PorcupineManager initialized successfully");
    } catch (e, stackTrace) {
      _logger.e("PORCUPINE INIT FAILURE", error: e, stackTrace: stackTrace);
      throw Exception("Porcupine init failed: ${e.toString()}");
    }
  }

  Future<String> _loadAsset(String assetName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$assetName';
      final file = File(filePath);

      if (!await file.exists()) {
        _logger.i("Copying $assetName to app directory: $filePath");
        final byteData = await rootBundle.load('assets/$assetName');
        await file.writeAsBytes(byteData.buffer.asUint8List());
      }
      return filePath;
    } catch (e) {
      _logger.e("Error loading asset $assetName: $e");
      throw Exception("Failed to load asset $assetName: $e");
    }
  }

  Future<void> _startListening() async {
    if (_porcupineManager == null) {
      _logger.e("PorcupineManager is not initialized.");
      setState(() => _statusMessage = "Porcupine not initialized. Please restart.");
      return;
    }
    if (!_isListening) {
      try {
        await _porcupineManager!.start();
        setState(() {
          _isListening = true;
          _statusMessage = "Listening for 'Hey Buddy'...";
        });
        _logger.i("Started listening for wake word");
      } catch (e, stackTrace) {
        _logger.e("Error starting PorcupineManager: $e",
            error: e, stackTrace: stackTrace);
        setState(() => _statusMessage = "Error starting listener: ${e.toString()}.");
      }
    }
  }

  void _onWakeWordDetected(int keywordIndex) {
    _logger.i("Wake word detected! Index: $keywordIndex");
    if (mounted) {
      setState(() {
        _isListening = false;
        _statusMessage = "Wake word detected! Processing...";
      });
      // TODO: Add post-wake word logic here.
    }
  }

  @override
  void dispose() {
    _logger.i("Disposing PorcupineManager");
    _porcupineManager?.stop();
    _porcupineManager?.delete();
    _porcupineManager = null;
    super.dispose();
    _logger.i("PorcupineManager disposed");
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("HeyBuddy")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _statusMessage,
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (_isInitialized)
                  ElevatedButton(
                    onPressed: _isListening ? null : _startListening,
                    child: Text(_isListening ? "Listening..." : "Start Listening"),
                  )
                else
                  const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
