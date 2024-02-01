import 'dart:convert';

import 'package:audio_2fa/const.dart';
import 'package:audio_2fa/home_web.dart';
import 'package:audio_2fa/register.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginDemo extends StatefulWidget {
  @override
  _LoginDemoState createState() => _LoginDemoState();
}

class _LoginDemoState extends State<LoginDemo> {
  String email = "";
  String password = "";

  showToast(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  save() async {
    try {
      Map<String, String> body = {
        "username": email,
        "password": password,
      };
      http.Response response = await http.post(Uri.parse(login_url), body: body);
      print(response.body);
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        showToast("Login success");
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        print(data['token']);
        await prefs.setString('token', data['token']!);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      } else {
        showToast("Login fail");
      }
    } catch (e) {
      print(e);
      showToast("Login fail");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Login Page"),
      ),
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("images/background_image.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Semi-Transparent Overlay
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
          SingleChildScrollView(
            child: Column(
              children: <Widget>[
                SizedBox(height: 30),
                Container(
                  child: Text(
                    "Login",
                    style: TextStyle(fontSize: 32, color: Colors.white),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  child: TextField(
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Email',
                      hintText: 'Enter valid email id',
                      labelStyle: TextStyle(color: Colors.white),
                      hintStyle: TextStyle(color: Colors.white70),
                    ),
                    onChanged: (e) {
                      email = e;
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  child: TextField(
                    style: TextStyle(color: Colors.white),
                    obscureText: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Password',
                      hintText: 'Enter secure password',
                      labelStyle: TextStyle(color: Colors.white),
                      hintStyle: TextStyle(color: Colors.white70),
                    ),
                    onChanged: (e) {
                      password = e;
                    },
                  ),
                ),
                InkWell(
                  onTap: () {
                    save();
                  },
                  child: Container(
                    alignment: Alignment.center,
                    margin: EdgeInsets.all(20),
                    height: 50,
                    width: 250,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Login',
                      style: TextStyle(color: Colors.white, fontSize: 25),
                    ),
                  ),
                ),
                Container(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => Register()),
                      );
                    },
                    child: Text(
                      "New Account - Register",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
