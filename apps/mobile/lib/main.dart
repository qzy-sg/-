import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: HouseApp()));
}

class HouseApp extends ConsumerWidget {
  const HouseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: '房屋设计助手',
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) {
        return ColoredBox(
          color: AppColors.page,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
