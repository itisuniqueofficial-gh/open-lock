/// Static app metadata — the single Dart-side source of truth for the app's
/// name, version, and maintainer/developer identity. The [version] mirrors the
/// `version:` in `pubspec.yaml`; bump both together on each release. Used by the
/// About screen and `.olbackup` export envelopes.
abstract final class AppInfo {
  static const String name = 'Open Lock';
  static const String version = '1.5.0';

  static const String maintainer = 'It Is Unique Official';
  static const String developer = 'Jaydatt Khodave';
  static const String website = 'https://openlock.itisuniqueofficial.com';
  static const String developerWebsite = 'https://jaydatt.pages.dev';
}
