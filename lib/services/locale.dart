import 'dart:async';

import 'package:dahlia_shared/generated/locale/data.dart';
import 'package:dahlia_shared/generated/locale/strings.dart';
import 'package:dahlia_shared/services/service.dart';
import 'package:intl/locale.dart';
import 'package:yatl_flutter/yatl_flutter.dart';
import 'package:yatl_gen/yatl_gen.dart';

class LocaleServiceFactory extends ServiceFactory<LocaleService> {
  const LocaleServiceFactory();

  @override
  LocaleService build() => _LocaleServiceImpl();
}

abstract class LocaleService extends Service {
  LocaleService();

  static LocaleService get current {
    return ServiceManager.getService<LocaleService>()!;
  }

  static const GeneratedLocales locales = GeneratedLocales();

  YatlCore get yatl;
  GeneratedLocaleStrings get strings;
}

class _LocaleServiceImpl extends LocaleService {
  YatlCore? _yatl;
  GeneratedLocaleStrings? _strings;

  @override
  YatlCore get yatl => _yatl!;

  @override
  GeneratedLocaleStrings get strings => _strings!;

  @override
  Future<void> start() async {
    _yatl = YatlCore(
      loader: const LocalesTranslationsLoader(LocaleService.locales),
      supportedLocales: LocaleService.locales.supportedLocales,
      fallbackLocale: Locale.parse("en_US"),
    );
    await _yatl!.init();
    _strings = GeneratedLocaleStrings(_yatl!);
  }

  @override
  void stop() {
    _yatl = null;
    _strings = null;
  }
}

LocaleService get _instance => LocaleService.current;

YatlCore get yatl => _instance.yatl;

GeneratedLocales get locales => LocaleService.locales;

GeneratedLocaleStrings get strings => _instance.strings;
