import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlock/src/core/di.dart';
import 'package:openlock/src/core/interfaces/enforcement_bridge.dart';

/// Recorded intruder events (failed-unlock bursts, optionally with a photo),
/// newest first, read from native storage.
final class IntruderController extends AsyncNotifier<List<IntruderRecord>> {
  @override
  Future<List<IntruderRecord>> build() =>
      ref.watch(enforcementBridgeProvider).getIntruderRecords();

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(enforcementBridgeProvider).getIntruderRecords(),
    );
  }

  Future<void> delete(String id) async {
    await ref.read(enforcementBridgeProvider).deleteIntruderRecord(id);
    await refresh();
  }

  Future<void> clearAll() async {
    await ref.read(enforcementBridgeProvider).clearIntruderRecords();
    await refresh();
  }
}

final intruderControllerProvider =
    AsyncNotifierProvider<IntruderController, List<IntruderRecord>>(
  IntruderController.new,
);
