import 'package:flutter/material.dart';

/// Global navigator key so push-notification taps can navigate without relying
/// on a BuildContext.
final GlobalKey<NavigatorState> notificationNavigatorKey = GlobalKey<NavigatorState>();

