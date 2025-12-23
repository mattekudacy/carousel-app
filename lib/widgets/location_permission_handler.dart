import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/location_service.dart';

/// Widget that displays location permission status and handles permission requests
class LocationPermissionHandler extends ConsumerWidget {
  final Widget child;
  final Widget? loadingWidget;

  const LocationPermissionHandler({
    super.key,
    required this.child,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionStatus = ref.watch(locationPermissionNotifierProvider);

    if (permissionStatus == LocationPermissionStatus.granted) {
      return child;
    }

    return _PermissionRequestScreen(
      status: permissionStatus,
      onRequestPermission: () {
        ref.read(locationPermissionNotifierProvider.notifier).requestPermissions();
      },
      onOpenSettings: () {
        ref.read(locationPermissionNotifierProvider.notifier).openSettings();
      },
      onRefresh: () {
        ref.read(locationPermissionNotifierProvider.notifier).refreshStatus();
      },
    );
  }
}

class _PermissionRequestScreen extends StatelessWidget {
  final LocationPermissionStatus status;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenSettings;
  final VoidCallback onRefresh;

  const _PermissionRequestScreen({
    required this.status,
    required this.onRequestPermission,
    required this.onOpenSettings,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Location Access'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                _getIcon(),
                size: 80,
                color: _getIconColor(context),
              ),
              const SizedBox(height: 24),
              Text(
                _getTitle(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _getMessage(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Status indicator
              _StatusCard(status: status),
              
              const SizedBox(height: 32),
              
              // Primary action button
              FilledButton.icon(
                onPressed: _getPrimaryAction(),
                icon: Icon(_getPrimaryActionIcon()),
                label: Text(_getPrimaryActionText()),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Secondary action (refresh)
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Check Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (status) {
      case LocationPermissionStatus.serviceDisabled:
        return Icons.location_off;
      case LocationPermissionStatus.deniedForever:
        return Icons.block;
      case LocationPermissionStatus.deniedOnce:
        return Icons.location_disabled;
      default:
        return Icons.location_searching;
    }
  }

  Color _getIconColor(BuildContext context) {
    switch (status) {
      case LocationPermissionStatus.serviceDisabled:
      case LocationPermissionStatus.deniedForever:
        return Colors.red;
      case LocationPermissionStatus.deniedOnce:
        return Colors.orange;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _getTitle() {
    switch (status) {
      case LocationPermissionStatus.serviceDisabled:
        return 'Location Services Disabled';
      case LocationPermissionStatus.deniedForever:
        return 'Location Access Blocked';
      case LocationPermissionStatus.deniedOnce:
        return 'Location Access Required';
      default:
        return 'Enable Location';
    }
  }

  String _getMessage() {
    switch (status) {
      case LocationPermissionStatus.serviceDisabled:
        return 'Please enable location services on your device to track your journey and receive station alerts.';
      case LocationPermissionStatus.deniedForever:
        return 'Location permission was permanently denied. Please enable it in your device settings to use the app.';
      case LocationPermissionStatus.deniedOnce:
        return 'We need access to your location to track your position and notify you when approaching your destination station.';
      default:
        return 'Location access is needed to provide station tracking and alerts.';
    }
  }

  VoidCallback _getPrimaryAction() {
    switch (status) {
      case LocationPermissionStatus.serviceDisabled:
      case LocationPermissionStatus.deniedForever:
        return onOpenSettings;
      default:
        return onRequestPermission;
    }
  }

  IconData _getPrimaryActionIcon() {
    switch (status) {
      case LocationPermissionStatus.serviceDisabled:
      case LocationPermissionStatus.deniedForever:
        return Icons.settings;
      default:
        return Icons.location_on;
    }
  }

  String _getPrimaryActionText() {
    switch (status) {
      case LocationPermissionStatus.serviceDisabled:
        return 'Open Location Settings';
      case LocationPermissionStatus.deniedForever:
        return 'Open App Settings';
      default:
        return 'Grant Location Access';
    }
  }
}

class _StatusCard extends StatelessWidget {
  final LocationPermissionStatus status;

  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getBorderColor()),
      ),
      child: Row(
        children: [
          Icon(
            _getStatusIcon(),
            color: _getBorderColor(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Permission Status',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getBorderColor(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (status) {
      case LocationPermissionStatus.granted:
        return Colors.green[50]!;
      case LocationPermissionStatus.serviceDisabled:
      case LocationPermissionStatus.deniedForever:
        return Colors.red[50]!;
      case LocationPermissionStatus.deniedOnce:
        return Colors.orange[50]!;
      default:
        return Colors.grey[100]!;
    }
  }

  Color _getBorderColor() {
    switch (status) {
      case LocationPermissionStatus.granted:
        return Colors.green;
      case LocationPermissionStatus.serviceDisabled:
      case LocationPermissionStatus.deniedForever:
        return Colors.red;
      case LocationPermissionStatus.deniedOnce:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case LocationPermissionStatus.granted:
        return Icons.check_circle;
      case LocationPermissionStatus.serviceDisabled:
        return Icons.location_off;
      case LocationPermissionStatus.deniedForever:
        return Icons.block;
      case LocationPermissionStatus.deniedOnce:
        return Icons.warning;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusText() {
    switch (status) {
      case LocationPermissionStatus.granted:
        return 'Granted';
      case LocationPermissionStatus.serviceDisabled:
        return 'Location Services Off';
      case LocationPermissionStatus.deniedForever:
        return 'Permanently Denied';
      case LocationPermissionStatus.deniedOnce:
        return 'Not Granted';
      default:
        return 'Unknown';
    }
  }
}

/// Compact permission status indicator widget
class LocationPermissionIndicator extends ConsumerWidget {
  const LocationPermissionIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(locationPermissionNotifierProvider);

    Color color;
    IconData icon;
    String text;

    switch (status) {
      case LocationPermissionStatus.granted:
        color = Colors.green;
        icon = Icons.location_on;
        text = 'Location Active';
        break;
      case LocationPermissionStatus.serviceDisabled:
        color = Colors.red;
        icon = Icons.location_off;
        text = 'GPS Off';
        break;
      case LocationPermissionStatus.deniedForever:
        color = Colors.red;
        icon = Icons.block;
        text = 'Blocked';
        break;
      case LocationPermissionStatus.deniedOnce:
        color = Colors.orange;
        icon = Icons.location_disabled;
        text = 'Not Allowed';
        break;
      default:
        color = Colors.grey;
        icon = Icons.location_searching;
        text = 'Checking...';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
