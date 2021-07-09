import 'package:flutter/material.dart';

import 'main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late double screenW, screenH;
  late TextEditingController _emailcontroller;
  late TextEditingController _passwordcontroller;
  @override
  void initState() {
    super.initState();
    _emailcontroller = TextEditingController();
    _passwordcontroller = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    screenW = MediaQuery.of(context).size.width;
    screenH = MediaQuery.of(context).size.height;
    return SafeArea(
        child: Scaffold(
            body: Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          height: screenW * 1.2,
          width: screenW * 0.9,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.deepOrange.shade400,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: text("Hello", 50),
              ),
              text("Sign into youur account", 20),
              SizedBox(
                height: screenH * 0.05,
              ),
              textTitle("Email"),
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius:
                        const BorderRadius.all(const Radius.circular(25)),
                  ),
                  child: TextField(
                    controller: _emailcontroller,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                        )),
                  ),
                ),
              ),
              SizedBox(
                height: screenH * 0.025,
              ),
              textTitle("Password"),
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius:
                        const BorderRadius.all(const Radius.circular(25)),
                  ),
                  child: TextField(
                    obscureText: true,
                    controller: _passwordcontroller,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                        prefixIcon: Icon(Icons.vpn_key),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                        )),
                  ),
                ),
              ),
              SizedBox(
                height: screenH * 0.08,
              ),

              // ignore: deprecated_member_use
              RaisedButton(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0)),
                color: Colors.amber.shade50,
                child: Text('Sign in',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.black54,
                    )),
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => ButtonPage()));
                },
              )
            ],
          ),
        ),
      ),
    )));
  }

  Padding textTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(left: 30, bottom: 2),
      child: Align(alignment: Alignment.centerLeft, child: text(t, 15)),
    );
  }

  Text text(String t, double s) {
    return Text(
      t,
      style: TextStyle(
        color: Colors.amber.shade50,
        fontSize: s,
      ),
    );
  }
}
