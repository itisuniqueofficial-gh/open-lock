import 'package:openlock/src/features/enforcement/models/relock_policy.dart';
import 'package:openlock/src/features/schedules/models/lock_schedule.dart';

/// The Flutter-side source of truth for everything the lock behaves by. Stored
/// encrypted at rest (AES-256-GCM, key in secure storage). The *subset* the
/// native monitor needs is projected via [toNativeMap] and pushed into the
/// native EncryptedSharedPreferences.
final class LockConfig {
  const LockConfig({
    this.lockedPackages = const {},
    this.lockNewApps = false,
    this.relock = const RelockPolicy(),
    this.randomizeKeypad = false,
    this.intruderCaptureEnabled = false,
    this.intruderThreshold = 3,
    this.fakeCoverEnabled = false,
    this.preventUninstall = false,
    this.schedules = const [],
  });

  /// Apps locked at all times (user toggles in the app picker).
  final Set<String> lockedPackages;

  /// Automatically lock apps installed after this was turned on.
  final bool lockNewApps;

  final RelockPolicy relock;

  /// Randomize the digit positions on the lock keypad (anti-shoulder-surf).
  final bool randomizeKeypad;

  final bool intruderCaptureEnabled;

  /// Failed attempts before an intruder photo is captured.
  final int intruderThreshold;

  /// Show a fake "app has stopped" decoy instead of the lock screen.
  final bool fakeCoverEnabled;

  /// Device-admin uninstall protection is on. Mirrors whether OpenLock is an
  /// active device administrator; also tells the native monitor to guard the
  /// OS deactivate-admin / app-info / uninstall screens.
  final bool preventUninstall;

  final List<LockSchedule> schedules;

  static const LockConfig empty = LockConfig();

  LockConfig copyWith({
    Set<String>? lockedPackages,
    bool? lockNewApps,
    RelockPolicy? relock,
    bool? randomizeKeypad,
    bool? intruderCaptureEnabled,
    int? intruderThreshold,
    bool? fakeCoverEnabled,
    bool? preventUninstall,
    List<LockSchedule>? schedules,
  }) =>
      LockConfig(
        lockedPackages: lockedPackages ?? this.lockedPackages,
        lockNewApps: lockNewApps ?? this.lockNewApps,
        relock: relock ?? this.relock,
        randomizeKeypad: randomizeKeypad ?? this.randomizeKeypad,
        intruderCaptureEnabled:
            intruderCaptureEnabled ?? this.intruderCaptureEnabled,
        intruderThreshold: intruderThreshold ?? this.intruderThreshold,
        fakeCoverEnabled: fakeCoverEnabled ?? this.fakeCoverEnabled,
        preventUninstall: preventUninstall ?? this.preventUninstall,
        schedules: schedules ?? this.schedules,
      );

  Map<String, dynamic> toJson() => {
        'lockedPackages': lockedPackages.toList()..sort(),
        'lockNewApps': lockNewApps,
        'relock': relock.toJson(),
        'randomizeKeypad': randomizeKeypad,
        'intruderCaptureEnabled': intruderCaptureEnabled,
        'intruderThreshold': intruderThreshold,
        'fakeCoverEnabled': fakeCoverEnabled,
        'preventUninstall': preventUninstall,
        'schedules': schedules.map((s) => s.toJson()).toList(),
      };

  factory LockConfig.fromJson(Map<String, dynamic> json) => LockConfig(
        lockedPackages: ((json['lockedPackages'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toSet(),
        lockNewApps: json['lockNewApps'] as bool? ?? false,
        relock: json['relock'] is Map<String, dynamic>
            ? RelockPolicy.fromJson(json['relock'] as Map<String, dynamic>)
            : const RelockPolicy(),
        randomizeKeypad: json['randomizeKeypad'] as bool? ?? false,
        intruderCaptureEnabled:
            json['intruderCaptureEnabled'] as bool? ?? false,
        intruderThreshold: (json['intruderThreshold'] as num?)?.toInt() ?? 3,
        fakeCoverEnabled: json['fakeCoverEnabled'] as bool? ?? false,
        preventUninstall: json['preventUninstall'] as bool? ?? false,
        schedules: ((json['schedules'] as List<dynamic>?) ?? const [])
            .map((e) => LockSchedule.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// The exact map handed to the native monitor. [pinHash]/[pinSalt] are the
  /// PBKDF2 verifier the on-top LockActivity checks entered PINs against; they
  /// live in secure storage and are merged in here at push time.
  Map<String, dynamic> toNativeMap({
    required String pinHash,
    required String pinSalt,
    bool biometricEnabled = false,
  }) =>
      {
        'lockedPackages': lockedPackages.toList()..sort(),
        'lockNewApps': lockNewApps,
        'relockMode': relock.mode.storageValue,
        'relockTimeoutMinutes': relock.timeout.inMinutes,
        'randomizeKeypad': randomizeKeypad,
        'intruderCaptureEnabled': intruderCaptureEnabled,
        'intruderThreshold': intruderThreshold,
        'fakeCoverEnabled': fakeCoverEnabled,
        'preventUninstall': preventUninstall,
        'biometricEnabled': biometricEnabled,
        'schedules': schedules.map((s) => s.toJson()).toList(),
        'pinHash': pinHash,
        'pinSalt': pinSalt,
        'pinIterations': 120000,
      };
}
