import 'package:flutter_web_plugins/url_strategy.dart';

/// Path URLs (`/admin/...`) instead of hash (`/#/admin/...`) for Firebase Hosting.
void configureWebUrlStrategy() {
  setUrlStrategy(PathUrlStrategy());
}
