import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import '../../core/localization/app_locale_controller.dart';

class LanguageSelectionPage extends ConsumerStatefulWidget {
  const LanguageSelectionPage({super.key, this.isFirstLaunch = false});

  final bool isFirstLaunch;

  @override
  ConsumerState<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends ConsumerState<LanguageSelectionPage> {
  AppLanguage _selectedLanguage = AppLanguage.english;

  @override
  void initState() {
    super.initState();
    final savedLanguage = ref.read(appLocaleControllerProvider).asData?.value;
    if (savedLanguage != null) _selectedLanguage = savedLanguage;
  }

  String _label(AppLocalizations localizations, AppLanguage language) {
    switch (language) {
      case AppLanguage.english:
        return localizations.english;
      case AppLanguage.hindi:
        return localizations.hindi;
      case AppLanguage.kannada:
        return localizations.kannada;
    }
  }

  Future<void> _save() async {
    await ref.read(appLocaleControllerProvider.notifier).select(_selectedLanguage);
    if (!mounted || widget.isFirstLaunch) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: widget.isFirstLaunch ? null : AppBar(title: Text(localizations.language)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                localizations.chooseLanguage,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 20),
              Card(
                child: RadioGroup<AppLanguage>(
                  groupValue: _selectedLanguage,
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedLanguage = value);
                  },
                  child: Column(
                    children: AppLanguage.values.map((language) {
                      return RadioListTile<AppLanguage>(
                        value: language,
                        title: Text(_label(localizations, language)),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                child: Text(localizations.continueLabel),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}