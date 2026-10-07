import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/push/push_service.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await initializeDateFormatting('ru_RU');
  Intl.defaultLocale = 'ru_RU';
  final container = ProviderContainer();
  await container.read(pushServiceProvider).bootstrap();
  runApp(UncontrolledProviderScope(
    container: container,
    child: const DavartApp(),
  ));
}
