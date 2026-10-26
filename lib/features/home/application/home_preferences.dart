import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di.dart';
import '../../../core/serial_queue.dart';

enum HomeLayoutMode { clock, compact }

class HomeLayout extends Notifier<HomeLayoutMode> {
  final _writes = SerialQueue();
  @override
  HomeLayoutMode build() => ref.read(sharedPreferencesProvider).getString('home.layout') == 'compact'
      ? HomeLayoutMode.compact : HomeLayoutMode.clock;

  Future<void> toggle() async {
    state = state == HomeLayoutMode.clock ? HomeLayoutMode.compact : HomeLayoutMode.clock;
    final value = state.name;
    final prefs = ref.read(sharedPreferencesProvider);
    await _writes.run(() async { await prefs.setString('home.layout', value); });
  }
}

final homeLayoutProvider = NotifierProvider<HomeLayout, HomeLayoutMode>(HomeLayout.new);
