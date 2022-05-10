// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:f_logs/f_logs.dart';
import 'package:flutter/services.dart';

void log2(String message, {name: "Airtable"}) {
  FLog.logThis(
    methodName: name,
    text: message,
    type: LogLevel.INFO,
    dataLogType: DataLogType.DEVICE.toString(),
  );
}

/// Plugin for fetching the app logs
class Logcat {
  /// [MethodChannel] used to communicate with the platform side.
  static const platform = const MethodChannel('app.channel.logcat');

  /// Fetches the app logs by executing the logcat command-line tool.
  /// May throw [PlatformException] from [MethodChannel].
  static Future<String> execute() async {
    if (Platform.isIOS) {
      return 'Logs can only be fetched from Android Devices presently.';
    }
    String logs;
    try {
      logs = await platform.invokeMethod('execLogcat');
    } on PlatformException catch (e) {
      logs = "Failed to get logs: '${e.message}'.";
    }

    return logs;
  }

  static Future<bool> zipLogFile(
      String srcFilePath, String dstFilePath, String key) async {
    bool bResult;
    try {
      if (Platform.isIOS) {
        bResult = await platform.invokeMethod('zipAndEncryptLogFile', {
          "srcFilePath": srcFilePath.toString(),
          "dstFilePath": dstFilePath.toString(),
          "key": key,
        });
      } else {
        bResult = await platform.invokeMethod('zipLogFile', {
          "srcFilePath": srcFilePath.toString(),
          "dstFilePath": dstFilePath.toString(),
          "key": key,
        });
      }
    } on MissingPluginException catch (e) {
      log2("MissingPluginException : ${e.toString()}");
    }
    return (bResult != null && bResult);
  }

  static encrypt(
      String plainFilePath, String cipherFilePath, String key) async {
    try {
      await platform.invokeMethod('encrypt', {
        "plainFilePath": plainFilePath.toString(),
        "cipherFilePath": cipherFilePath.toString(),
        "key": key,
      });
    } on MissingPluginException catch (e) {
      log2("MissingPluginException : ${e.toString()}");
    }
  }

  static Future<bool> isAutoRotateMode() async {
    if (Platform.isIOS) {
      log("Platform iOS");
      try {
        log("try");
        return await platform.invokeMethod(
            "shouldAutorotateToInterfaceOrientation",
            {"toInterfaceOrientation": 5});
      } on PlatformException catch (e) {
        log("Failed to : ${e.toString()}");
      }

      log("Failed get isAutoRotateMode");
      return false;
    }

    try {
      return await platform.invokeMethod('isAutoRotateMode');
    } on PlatformException catch (e) {
      print("Failed to : ${e.toString()}");
    }
    print("Failed get isAutoRotateMode");
    return false;
  }
}
