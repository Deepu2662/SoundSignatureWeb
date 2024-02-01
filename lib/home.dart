import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound_record/flutter_sound_record.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

import 'const.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late WebSocketChannel channel;
  String wsweb = "Disconnected";
  String token = "";
  String aid = "";
  Future<void> wsconnect() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token')!;
    channel = WebSocketChannel.connect(
      Uri.parse('ws://iot.appblocky.com:8002/ws/iot/$token/'),
    );

    channel.stream.listen(
          (data) {
        print("data is $data");
        Map<dynamic, dynamic> data1 = jsonDecode((data.toString()));
        String msg = data1['message'];
        if (msg.contains("web")) {
          setState(() {
            wsweb = "Online";
          });
          if (msg.contains("rec")) {
            _start();
          }
          if (msg.contains("stop")) {
            _stop();
            setState(() {
              _isVerifying = true;
            });
          }
          if (msg.contains("aid")) {
            aid = msg.substring(msg.length - 5);
            print("aid: $aid");
          }

          if (msg.contains("verify")) {
            if (msg.contains("process")) {
              setState(() {
                _isVerifying = true;
              });
            }
            if (msg.contains("success")) {
              setState(() {
                _isVerifying = false;
                error_msg = "Verification Success";
              });
            }
            if (msg.contains("fail")) {
              setState(() {
                _isVerifying = false;
                error_msg = "Verification Failed";
              });
            }
          }
        } else {
          setState(() {
            wsweb = "Offline";
          });
        }
      },
      onError: (error) {
        print("error is $error");
      },
    );
  }

  @override
  void initState() {
    super.initState();
    getPerm();
    wsconnect();
    _isRecording = false;
  }

  getPerm() async {
    await _audioRecorder.hasPermission();
  }

  final FlutterSoundRecord _audioRecorder = FlutterSoundRecord();
  bool _isRecording = false;
  bool _isPaused = false;
  int _recordDuration = 0;

  Future<void> _start() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start();

        bool isRecording = await _audioRecorder.isRecording();
        setState(() {
          _isRecording = isRecording;
          _recordDuration = 0;
        });
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _stop() async {
    setState(() {
      _isVerifying = true;
    });
    try {
      final String? path = await _audioRecorder.stop();

      print(path);

      if (true) {
        final blobFilePath = path;
        if (blobFilePath != null) {
          if (kIsWeb) {}
          Uri uri1 = Uri.parse(upload_url);
          var request1 = http.MultipartRequest('POST', uri1);
          request1.headers.addAll({"Authorization": "token $token"});
          if (Platform.isAndroid) {
            request1.fields.addAll({"aid": aid, "type": "mob"});
            request1.files.add(
                await http.MultipartFile.fromPath('audio', blobFilePath));
          } else {
            request1.fields.addAll({"aid": aid, "type": "web"});
            final uri = Uri.parse(blobFilePath);
            final client = http.Client();
            final request = await client.get(uri);
            print(request.headers);
            final bytes = await request.bodyBytes;
            print('response bytes.length: ${bytes.length}');
            request1.files.add(http.MultipartFile.fromBytes(
              "audio",
              bytes,
              filename: "audio.m4a",
            ));
          }
          var response = await request1.send();
          setState(() => _isRecording = false);
        }
      }
    } catch (e) {
      print(e);
    }
  }

  String _formatNumber(int number) {
    String numberStr = number.toString();
    if (number < 10) {
      numberStr = '0$numberStr';
    }

    return numberStr;
  }

  Widget _buildTimer() {
    final String minutes = _formatNumber(_recordDuration ~/ 60);
    final String seconds = _formatNumber(_recordDuration % 60);

    return Text(
      '$minutes : $seconds',
      style: const TextStyle(color: Colors.red),
    );
  }

  Timer? _timer;
  Timer? _ampTimer;
  Amplitude? _amplitude;

  void _startTimer() {
    _timer?.cancel();
    _ampTimer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });

    _ampTimer =
        Timer.periodic(const Duration(milliseconds: 200), (Timer t) async {
          _amplitude = await _audioRecorder.getAmplitude();
          print("Amplitude: ${_amplitude!.current}");
          setState(() {});
        });
  }

  Future<void> _pause() async {
    setState(() => _isPaused = true);
  }

  Future<void> _resume() async {
    setState(() => _isPaused = false);
  }

  bool _isVerifying = false;
  String error_msg = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Home 2FA"),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("images/background_image.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Status: $wsweb",
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
            _isRecording
                ? Column(
              children: [
                Container(
                  child: SpinKitWave(
                    color: Colors.blue,
                  ),
                ),
                Text(
                  "Processing..",
                  style: TextStyle(fontSize: 15, color: Colors.white),
                ),
              ],
            )
                : Container(),
            _isVerifying
                ? Column(
              children: [
                Container(
                  child: SpinKitFadingCircle(
                    color: Colors.blue,
                  ),
                ),
                Text(
                  "Verifying..",
                  style: TextStyle(fontSize: 15, color: Colors.white),
                ),
              ],
            )
                : Container(),
            Container(
              child: Text(
                "$error_msg",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Add your button action here
              },
              child: Text(
                'Custom Action',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                primary: Colors.blue,
                onPrimary: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
