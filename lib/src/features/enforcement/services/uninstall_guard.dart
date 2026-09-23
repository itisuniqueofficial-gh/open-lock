/// Pure decision for the uninstall-protection screen guard, mirrored exactly by
/// the Kotlin `LockLogic.shouldGuardUninstall`. Given the foreground package
/// and its activity class while "Prevent uninstall" is on, it decides whether
/// OpenLock should throw up the lock screen to guard the OS path that could
/// deactivate device admin or uninstall the app.
///
/// This is a **best-effort**, Android-version- and OEM-dependent heuristic: it
/// keys off the Settings / package-installer activity that comes to the
/// foreground. Some OEMs and newer Android releases label or restrict these
/// screens differently, so it cannot be guaranteed on every device. Because the
/// app-info / uninstall screen does not tell us *which* app is being viewed, it
/// may also trigger while inspecting another app's info page.
abstract final class UninstallGuard {
  const UninstallGuard._();

  /// The system Settings package whose device-admin and app-info screens we
  /// guard.
  static const String settingsPackage = 'com.android.settings';

  /// Substrings of Settings activity class names that indicate the
  /// deactivate-admin, app-info, or uninstall screens.
  static const List<String> settingsClassHints = [
    'deviceadmin', // com.android.settings.DeviceAdminAdd / DeviceAdminSettings
    'installedappdetails', // classic App info screen
    'appinfodashboard', // newer App info screen
    'applicationdetails',
    'uninstall',
  ];

  static bool shouldGuard({
    required bool preventUninstall,
    required String package,
    String? className,
  }) {
    if (!preventUninstall) return false;
    if (isPackageInstaller(package)) return true;
    if (package == settingsPackage) {
      if (className == null) return false;
      final lower = className.toLowerCase();
      return settingsClassHints.any(lower.contains);
    }
    return false;
  }

  /// The stock or Google package-installer, which hosts the uninstall
  /// confirmation dialog.
  static bool isPackageInstaller(String package) =>
      package == 'com.android.packageinstaller' ||
      package == 'com.google.android.packageinstaller' ||
      package.endsWith('.packageinstaller');
}
