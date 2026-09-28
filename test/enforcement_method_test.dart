import 'package:flutter_test/flutter_test.dart';
import 'package:openlock/src/core/interfaces/enforcement_bridge.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';

void main() {
  test('enforcement method persists through the config projection', () {
    const original = LockConfig(
      enforcementMethod: EnforcementMethod.accessibility,
    );

    final restored = LockConfig.fromJson(original.toJson());
    final native = original.toNativeMap(pinHash: 'hash', pinSalt: 'salt');

    expect(restored.enforcementMethod, EnforcementMethod.accessibility);
    expect(native['enforcementMethod'], 'accessibility');
  });

  test('missing enforcement method keeps the backward-compatible Usage default',
      () {
    expect(
      LockConfig.fromJson(const {}).enforcementMethod,
      EnforcementMethod.usageAccess,
    );
  });

  test('permission activity follows the selected method', () {
    const accessibility = PermissionStates(
      usageAccess: false,
      overlay: false,
      notifications: false,
      batteryExempt: false,
      serviceRunning: true,
      accessibilityService: true,
      enforcementMethod: 'accessibility',
    );
    const usage = PermissionStates(
      usageAccess: true,
      overlay: true,
      notifications: false,
      batteryExempt: false,
      serviceRunning: true,
      enforcementMethod: 'usageAccess',
    );

    expect(accessibility.canEnforce, isTrue);
    expect(accessibility.protectionActive, isTrue);
    expect(usage.canEnforce, isTrue);
    expect(usage.protectionActive, isTrue);
  });

  test('usage is not active when overlay is revoked', () {
    const state = PermissionStates(
      usageAccess: true,
      overlay: false,
      notifications: true,
      batteryExempt: true,
      serviceRunning: true,
    );

    expect(state.canEnforce, isFalse);
    expect(state.protectionActive, isFalse);
  });
}
