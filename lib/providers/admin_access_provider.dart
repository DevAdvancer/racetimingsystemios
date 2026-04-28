import 'package:flutter_riverpod/flutter_riverpod.dart';

final adminAccessProvider = NotifierProvider<AdminAccessController, bool>(
  AdminAccessController.new,
);

class AdminAccessController extends Notifier<bool> {
  @override
  bool build() => true;

  void unlock() {
    state = true;
  }

  void lock() {
    state = false;
  }
}
