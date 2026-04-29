import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

void goToAppRoute(BuildContext fallbackContext, String location) {
  final rootContext = appNavigatorKey.currentContext;
  final context = rootContext != null && rootContext.mounted
      ? rootContext
      : fallbackContext;
  GoRouter.of(context).go(location);
}
