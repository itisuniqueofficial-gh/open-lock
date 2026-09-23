import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlock/src/core/di.dart';
import 'package:openlock/src/core/storage_keys.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';

/// High-level authentication state for opening the OpenLock app itself.
enum AuthStatus { unknown, needsSetup, locked, unlocked }

/// Whether the first-run intro pages have been seen.
final onboardingSeenProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  return await storage.read(key: OpenLockKeys.onboardingSeen) == 'true';
});

final class SessionNotifier extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    _resolve();
    return AuthStatus.unknown;
  }

  Future<void> _resolve() async {
    final hasPin = await ref.read(pinAuthServiceProvider).hasPin();
    state = hasPin ? AuthStatus.locked : AuthStatus.needsSetup;
  }

  /// Records that the intro pages were seen and refreshes the flag.
  Future<void> completeOnboarding() async {
    await ref
        .read(secureStorageProvider)
        .write(key: OpenLockKeys.onboardingSeen, value: 'true');
    ref.invalidate(onboardingSeenProvider);
  }

  /// First-run PIN creation. Pushes the initial config to native and unlocks.
  Future<void> completeSetup(String pin) async {
    await ref.read(pinAuthServiceProvider).setupPin(pin);
    await ref.read(configControllerProvider.notifier).pushToNative();
    state = AuthStatus.unlocked;
  }

  void markUnlocked() => state = AuthStatus.unlocked;

  Future<void> lock() async {
    final hasPin = await ref.read(pinAuthServiceProvider).hasPin();
    state = hasPin ? AuthStatus.locked : AuthStatus.needsSetup;
  }
}

final sessionProvider =
    NotifierProvider<SessionNotifier, AuthStatus>(SessionNotifier.new);
