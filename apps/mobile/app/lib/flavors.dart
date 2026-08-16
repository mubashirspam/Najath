enum Flavor {
  dev,
  staging,
  prod,
}

class F {
  static late final Flavor appFlavor;

  static String get name => appFlavor.name;

  static String get title {
    switch (appFlavor) {
      case Flavor.dev:
        return 'Najath Dev';
      case Flavor.staging:
        return 'Najath Stg';
      case Flavor.prod:
        return 'Najath';
    }
  }
}
