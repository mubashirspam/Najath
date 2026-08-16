import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:najath/app.dart';
import 'package:najath/flavors.dart';

void main() {
  // `appFlavor` is injected by `flutter run/build --flavor <name>`.
  F.appFlavor = Flavor.values.firstWhere(
    (element) => element.name == appFlavor,
  );

  runApp(const App());
}
