import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, hindi, kannada }

extension AppLanguageDetails on AppLanguage {
  Locale get locale {
    switch (this) {
      case AppLanguage.english:
        return const Locale('en');
      case AppLanguage.hindi:
        return const Locale('hi');
      case AppLanguage.kannada:
        return const Locale('kn');
    }
  }

  String get storageValue => locale.languageCode;

  static AppLanguage? fromStorageValue(String? value) {
    for (final language in AppLanguage.values) {
      if (language.storageValue == value) return language;
    }
    return null;
  }
}

final appLocaleControllerProvider =
    AsyncNotifierProvider<AppLocaleController, AppLanguage?>(AppLocaleController.new);

class AppLocaleController extends AsyncNotifier<AppLanguage?> {
  static const _preferenceKey = 'app.language';

  @override
  Future<AppLanguage?> build() async {
    final preferences = await SharedPreferences.getInstance();
    return AppLanguageDetails.fromStorageValue(preferences.getString(_preferenceKey));
  }

  Future<void> select(AppLanguage language) async {
    state = AsyncData(language);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, language.storageValue);
  }
}