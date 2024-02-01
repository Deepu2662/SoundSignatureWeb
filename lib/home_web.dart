import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audio_2fa/user_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound_record/flutter_sound_record.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

import 'const.dart';

import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ////////////////////////////////////////////////
  Future<void> convertAndUploadBlobToAudio(String blobUrl) async {
    // Step 1: Fetch Blob data
    html.HttpRequest request =
    await html.HttpRequest.request(blobUrl, responseType: 'blob');
    html.Blob blob = request.response;

    // Step 2: Convert Blob data to audio file format (if needed)
    Uint8List audioData = await blobToUint8List(blob);

    // Step 3: Upload audio file to server URL
    await uploadAudioData(audioData);
  }

  Future<Uint8List> blobToUint8List(html.Blob blob) async {
    var completer = Completer<Uint8List>();
    var reader = html.FileReader();

    reader.onLoadEnd.listen((e) {
      completer.complete(reader.result as Uint8List);
    });

    reader.onError.listen((e) {
      completer.completeError(e);
    });

    reader.readAsArrayBuffer(blob);
    return completer.future;
  }

  late Timer st;
  Future<void> uploadAudioData(Uint8List audioData) async {
    // Perform the upload using HTTP POST request
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      token = prefs.getString('token')!;

      String url = upload_url;
      html.HttpRequest request = await html.HttpRequest.postFormData(
          url, {'audio': base64.encode(audioData), 'type': "web", "aid": aid},
          requestHeaders: {"Authorization": "token $token"});
      print('Upload successful: ${request.responseText}');
      st = Timer.periodic(Duration(seconds: 3), (timer) {
        verify();
      });
    } catch (e) {
      print('Error uploading audio: $e');
    }
  }

////////////////////////////////

  showToast(String msg){
    Fluttertoast.showToast(
        msg: msg,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0
    );
  }
  bool _isVerifying=false;
  bool _verified=false;
  String error_msg="";
  verify() async {
    try {

      String data1 = """{"message":"web-verify-process"}""";
      channel.sink.add(data1);
      setState(() {
        _isRecording=false;
        _isVerifying=true;
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      token = prefs.getString('token')!;
      http.Response resp = await http.post(Uri.parse(verify_url),
          body: {"aid":aid},
          headers: {"Authorization": "token $token"});
      print(resp.body);
      if (resp.statusCode == 200) {

        Map<String,dynamic> data=jsonDecode(resp.body);
        if(data['match']) {
          String data1 = """{"message":"web-verify-success"}""";
          channel.sink.add(data1);
          print("Verification success");
          st.cancel();
          setState(() {
            _isVerifying = false;
            _verified = true;
          });
          showToast("Verification success");

          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => UserMain()));
        }
        else{
          st.cancel();

          String data1 = """{"message":"web-verify-fail"}""";
          channel.sink.add(data1);

          setState(() {
            _isVerifying=false;
            _verified=false;

          });
          showToast("Verification failed");
        }
      }
      else if(resp.statusCode==412){
        print("processing");
      }
      else {
        st.cancel();

        String data1 = """{"message":"web-verify-fail"}""";
        channel.sink.add(data1);

        setState(() {
          _isVerifying=false;
          _verified=false;
          error_msg="Unable to verify";
        });
        showToast("Verification failed");

      }
    } catch (e) {

      String data1 = """{"message":"web-verify-fail"}""";
      channel.sink.add(data1);

      setState(() {
        _isVerifying=false;
        _verified=false;
        error_msg="Unable to verify";

      });
      showToast("Verification failed");

      print(e);
    }
  }
  ////////////////////////////////////////////////

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

    /// Listen for all incoming data
    channel.stream.listen(
          (data) {
        print("data is $data");
        Map<dynamic, dynamic> data1 = jsonDecode((data.toString()));
        String msg = data1['message'];
        // if (msg.contains("web")) {
        //   setState(() {
        //     wsweb = "Online";
        //   });
        //   if (msg.contains("rec")) {
        //     _start();
        //     Future.delayed(Duration(seconds: 5), () {
        //       _stop();
        //     });
        //   }
        //   if (msg.contains("aid")) {
        //     aid = msg.substring(msg.length - 5);
        //     print("aid: $aid");
        //   }
        // } else {
        //   setState(() {
        //     wsweb = "Offline";
        //   });
        // }
      },
      onError: (error) {
        print("error is $error");
      },
    );

    String data = """{"message":"web-online"}""";
    channel.sink.add(data);
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getPerm();
    wsconnect();
    _isRecording = false;
  }


  getPerm() async {
    await _audioRecorder.hasPermission();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _audioRecorder.dispose();
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
        // _startTimer();
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _stop() async {
    setState(() {
      _isRecording=false;
      _isVerifying=true;
    });
    try {
      final String? path = await _audioRecorder.stop();

      print(path);

      if (true) {
        final blobFilePath = path;
        convertAndUploadBlobToAudio(blobFilePath!);
        // if (blobFilePath != null) {
        //   // Set API endpoint URL
        //   Uri uri1 = Uri.parse(upload_url);
        //
        //   // Create multipart request
        //   var request1 = http.MultipartRequest('POST', uri1);
        //
        //   // var bytesData = bd.
        //
        //   final SharedPreferences prefs = await SharedPreferences.getInstance();
        //   token = prefs.getString('token')!;
        //   // request1.headers.addAll({"Authorization": "token $token"});
        //   // if (Platform.isAndroid) {
        //   //   request1.fields.addAll({"aid": aid, "type": "mob"});
        //   //
        //   //   request1.files
        //   //       .add(await http.MultipartFile.fromPath('audio', blobFilePath));
        //   // } else {
        //   //   request1.fields.addAll({"aid": aid, "type": "web"});
        //   //
        //   //   final uri = Uri.parse(blobFilePath);
        //   //   final client = http.Client();
        //   //   final request = await client.get(uri);
        //   //   print(request.headers);
        //   //   final bytes = await request.bodyBytes;
        //   //   print('response bytes.length: ${bytes.length}');
        //   //   request1.files.add(http.MultipartFile.fromBytes(
        //   //     "audio",
        //   //     bytes,
        //   //     filename: "audio.m4a",
        //   //   ));
        //   // // }
        //   // // Send request
        //   // var response = await request1.send();
        //   setState(() => _isRecording = false);
        // }
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

  static const _chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  Random _rnd = Random();

  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Verification"),
        backgroundColor: Colors.blue, // Customize the app bar color
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("images/background_image.jpg"), // Set your background image
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _isRecording?Column(
              children: [
                Container(
                  child: SpinKitWave(color: Colors.blue,),
                ),
                Text("Processing..",style: TextStyle(fontSize: 15),),
              ],
            ):Container(),

            _isVerifying?Column(
              children: [
                Container(
                  child: SpinKitFadingCircle(color: Colors.blue,),
                ),
                Text("Verifying..",style: TextStyle(fontSize: 15),),
              ],
            ):Container(),
            Container(
              child: Text("$error_msg"),
            ),
            Container(
              margin: EdgeInsets.all(20),
              child: ElevatedButton(
                  onPressed: () async {
                    aid = getRandomString(5);

                    String data = """{"message":"web-aid-$aid"}""";
                    channel.sink.add(data);
                    await Future.delayed(Duration(seconds: 1));
                    String data1 = """{"message":"web-rec"}""";
                    channel.sink.add(data1);

                    _start();
                    await Future.delayed(Duration(seconds: 30), () {
                      String data1 = """{"message":"web-stop"}""";
                      channel.sink.add(data1);
                      _stop();
                    });
                  },
                  child: Text("Start Verification")),
            )
          ],
        ),
      ),
    );
  }
}
