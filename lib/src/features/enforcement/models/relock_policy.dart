/// When a previously-unlocked app should be re-locked.
enum RelockMode {
  /// Re-lock the instant the user leaves the app (or the screen turns off).
  immediately,

  /// Stay unlocked for [RelockPolicy.timeout] after leaving; re-lock once it
  /// elapses. Returning within the window keeps the app open.
  afterTimeout,

  /// Re-lock only when the screen turns off; stays unlocked across app
  /// switches while the screen is on.
  onScreenOff;

  String get storageValue => name;

  static RelockMode fromStorage(String? value) {
    return RelockMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => RelockMode.immediately,
    );
  }
}

/// The relock mode plus its timeout (only meaningful for
/// [RelockMode.afterTimeout]).
final class RelockPolicy {
  const RelockPolicy({
    this.mode = RelockMode.immediately,
    this.timeout = const Duration(minutes: 1),
  });

  final RelockMode mode;
  final Duration timeout;

  /// The timeout choices surfaced in the UI.
  static const List<Duration> timeoutChoices = [
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];

  RelockPolicy copyWith({RelockMode? mode, Duration? timeout}) => RelockPolicy(
        mode: mode ?? this.mode,
        timeout: timeout ?? this.timeout,
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.storageValue,
        'timeoutMinutes': timeout.inMinutes,
      };

  factory RelockPolicy.fromJson(Map<String, dynamic> json) => RelockPolicy(
        mode: RelockMode.fromStorage(json['mode'] as String?),
        timeout:
            Duration(minutes: (json['timeoutMinutes'] as num?)?.toInt() ?? 1),
      );
}
