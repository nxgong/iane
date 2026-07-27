import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  static Future<bool> requestAll() async {
    final permissions = <Permission>[
      Permission.camera,
      Permission.microphone,
      Permission.notification,
    ];

    if (Platform.isAndroid) {
      permissions.add(Permission.location);
      permissions.add(Permission.photos);
    } else if (Platform.isIOS) {
      permissions.add(Permission.locationWhenInUse);
      permissions.add(Permission.photos);
    }

    final statuses = await permissions.request();

    bool granted = true;

    statuses.forEach((permission, status) {
      print("$permission : $status");
      if (!status.isGranted) {
        granted = false;
      }
    });

    return granted;
  }

  static Future<bool> requestLocation() async {
    PermissionStatus status;

    if (Platform.isAndroid) {
      status = await Permission.location.request();
    } else {
      status = await Permission.locationWhenInUse.request();
    }

    print("GPS : $status");

    return status.isGranted;
  }
}