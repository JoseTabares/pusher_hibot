import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pusher_hibot/pusher_hibot.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // String platformVersion;
    // // Platform messages may fail, so we use a try/catch PlatformException.
    // try {
    //   platformVersion = await PusherHibot.platformVersion;
    // } on PlatformException {
    //   platformVersion = 'Failed to get platform version.';
    // }

    // // If the widget was removed from the tree while the asynchronous platform
    // // message was in flight, we want to discard the reply rather than calling
    // // setState to update our non-existent appearance.
    // if (!mounted) return;

    // setState(() {
    //   _platformVersion = platformVersion;
    // });

    // PusherHibot.init(
    //   //   Application().pusherParams.appKey,
    // //   PusherOptions(
    // //     cluster: Application().pusherParams.cluster,
    // //     encrypted: true,
    // //     auth: PusherAuth(
    // //       Application().pusherParams.endpoint,
    // //       headers: {
    // //         HttpHeaders.authorizationHeader: 'Bearer ${Application().token}'
    // //       },
    // //     ),
    // //   ),
    // //   enableLogging: true,
    // );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Text('Running on: $_platformVersion\n'),
        ),
      ),
    );
  }
}
