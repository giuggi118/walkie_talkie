import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:web_socket_channel/io.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const WalkieTalkieApp());
}

class WalkieTalkieApp extends StatelessWidget {
  const WalkieTalkieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Walkie Talkie',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const WalkieTalkieScreen(),
    );
  }
}

class WalkieTalkieScreen extends StatefulWidget {
  const WalkieTalkieScreen({super.key});

  @override
  State<WalkieTalkieScreen> createState() => _WalkieTalkieScreenState();
}

class _WalkieTalkieScreenState extends State<WalkieTalkieScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  IOWebSocketChannel? _channel;

  bool _isConnected = false;
  bool _isRecording = false;
  String _statusMessage = 'Disconnesso';
  String? _tempPath;

  // Inserisci l'URL del tuo server Render (es. wss://walkie-talkie-server.onrender.com)
  final String _serverUrl = 'wss://walkie-talkie-server.onrender.com';

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _connectWebSocket();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  void _connectWebSocket() {
    try {
      _channel = IOWebSocketChannel.connect(Uri.parse(_serverUrl));
      setState(() {
        _isConnected = true;
        _statusMessage = 'Connesso al server';
      });

      _channel!.stream.listen(
        (data) async {
          if (data is List<int>) {
            await _playAudio(data);
          }
        },
        onError: (error) {
          setState(() {
            _isConnected = false;
            _statusMessage = 'Errore di connessione';
          });
        },
        onDone: () {
          setState(() {
            _isConnected = false;
            _statusMessage = 'Disconnesso';
          });
        },
      );
    } catch (e) {
      setState(() {
        _isConnected = false;
        _statusMessage = 'Impossibile connettersi';
      });
    }
  }

  Future<void> _startRecording() async {
    if (!_isConnected) return;

    if (await _audioRecorder.hasPermission()) {
      final Directory tempDir = await getTemporaryDirectory();
      _tempPath = '${tempDir.path}/audio_temp.aac';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _tempPath!,
      );

      setState(() {
        _isRecording = true;
        _statusMessage = 'Registrazione in corso...';
      });
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _statusMessage = 'Connesso al server';
    });

    if (path != null && _channel != null) {
      final bytes = await File(path).readAsBytes();
      _channel!.sink.add(bytes);
    }
  }

  Future<void> _playAudio(List<int> bytes) async {
    final Directory tempDir = await getTemporaryDirectory();
    final File tempFile = File('${tempDir.path}/incoming_audio.aac');
    await tempFile.writeAsBytes(bytes);

    await _audioPlayer.play(DeviceFileSource(tempFile.path));
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Walkie Talkie'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isConnected ? Icons.cloud_done : Icons.cloud_off,
              size: 48,
              color: _isConnected ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 12),
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 48),
            GestureDetector(
              onTapDown: (_) => _startRecording(),
              onTapUp: (_) => _stopRecording(),
              onTapCancel: () => _stopRecording(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? Colors.red : Colors.deepOrange,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? Colors.red : Colors.deepOrange)
                          .withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.mic : Icons.mic_none,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isRecording ? 'RILASCIA PER INVIARE' : 'TIENI PREMUTO PER PARLARE',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}