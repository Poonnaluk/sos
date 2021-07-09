import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos/main.dart';

Future<Null> normalDialog(
    BuildContext context, String string1, String string2) async {
  showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Container(
            margin: EdgeInsets.only(bottom: 10),
            child: Text(string1,
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ),
          content: Text(string2,
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          actions: [
            // ignore: deprecated_member_use
            FlatButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("ยกเลิก",
                  style: TextStyle(
                      color: Colors.red.shade500, fontWeight: FontWeight.bold)),
            ),
            // ignore: deprecated_member_use
            FlatButton(
              onPressed: () {
                Navigator.push(
                    context, MaterialPageRoute(builder: (context) => ButtonPage()));
              },
              child: Text("ยืนยัน",
                  style: TextStyle(
                      color: Colors.deepOrange.shade300,
                      fontWeight: FontWeight.bold)),
            )
          ],
        );
      });
}
