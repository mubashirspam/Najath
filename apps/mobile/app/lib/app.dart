import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:najath/flavors.dart';
import 'package:najath/pages/my_home_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: F.title,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF0F6E4F)),
      home: _flavorBanner(child: const MyHomePage(), show: kDebugMode),
    );
  }

  Widget _flavorBanner({required Widget child, required bool show}) => show
      ? Banner(
          location: BannerLocation.topStart,
          message: F.name,
          color: Colors.green.withAlpha(150),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 1,
          ),
          textDirection: TextDirection.ltr,
          child: child,
        )
      : child;
}
