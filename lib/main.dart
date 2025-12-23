import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/direction_selection_screen.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'widgets/location_permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification service
  await NotificationService().initialize();
  
  runApp(const ProviderScope(child: CarouselApp()));
}

class CarouselApp extends ConsumerWidget {
  const CarouselApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    
    return MaterialApp(
      title: 'Carousel App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode.themeMode,
      home: const LocationPermissionHandler(
        child: DirectionSelectionScreen(),
      ),
    );
  }
}
