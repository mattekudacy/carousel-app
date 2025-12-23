import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/location_tracking_service.dart';

/// Widget that displays live location data
class LiveLocationDisplay extends ConsumerWidget {
  final bool showDetails;

  const LiveLocationDisplay({
    super.key,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(locationTrackingNotifierProvider);
    final lastUpdate = trackingState.lastUpdate;

    if (!trackingState.isTracking) {
      return _buildNotTrackingState(context, ref);
    }

    if (lastUpdate == null) {
      return _buildWaitingState(context);
    }

    return _buildTrackingState(context, ref, lastUpdate);
  }

  Widget _buildNotTrackingState(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off, color: Colors.grey[400]),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Location tracking inactive',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(locationTrackingNotifierProvider.notifier).startTracking();
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Text('Acquiring GPS signal...'),
        ],
      ),
    );
  }

  Widget _buildTrackingState(
    BuildContext context,
    WidgetRef ref,
    LocationUpdate update,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GPS Active',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      'Accuracy: ${update.accuracy.toStringAsFixed(0)}m',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Speed display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.speed,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${update.speedKmh.toStringAsFixed(1)} km/h',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (showDetails) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            
            // Coordinates
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    context,
                    'Latitude',
                    update.latitude.toStringAsFixed(6),
                    Icons.arrow_upward,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDetailItem(
                    context,
                    'Longitude',
                    update.longitude.toStringAsFixed(6),
                    Icons.arrow_forward,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    context,
                    'Raw Speed',
                    '${update.rawSpeedKmh.toStringAsFixed(1)} km/h',
                    Icons.speed,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDetailItem(
                    context,
                    'Smoothed',
                    '${update.speedKmh.toStringAsFixed(1)} km/h',
                    Icons.trending_flat,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Compact speed indicator widget
class SpeedIndicator extends ConsumerWidget {
  const SpeedIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(locationTrackingNotifierProvider);
    final lastUpdate = trackingState.lastUpdate;

    if (!trackingState.isTracking || lastUpdate == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              '-- km/h',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.speed,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            '${lastUpdate.speedKmh.toStringAsFixed(1)} km/h',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// GPS signal strength indicator
class GpsSignalIndicator extends ConsumerWidget {
  const GpsSignalIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(locationTrackingNotifierProvider);
    final lastUpdate = trackingState.lastUpdate;

    Color color;
    String label;
    int signalBars;

    if (!trackingState.isTracking) {
      color = Colors.grey;
      label = 'Off';
      signalBars = 0;
    } else if (lastUpdate == null) {
      color = Colors.orange;
      label = 'Searching';
      signalBars = 1;
    } else if (lastUpdate.accuracy <= 10) {
      color = Colors.green;
      label = 'Excellent';
      signalBars = 4;
    } else if (lastUpdate.accuracy <= 20) {
      color = Colors.green;
      label = 'Good';
      signalBars = 3;
    } else if (lastUpdate.accuracy <= 50) {
      color = Colors.orange;
      label = 'Fair';
      signalBars = 2;
    } else {
      color = Colors.red;
      label = 'Poor';
      signalBars = 1;
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
          // Signal bars
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (index) {
              final isActive = index < signalBars;
              return Container(
                width: 3,
                height: 6.0 + (index * 3),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: isActive ? color : Colors.grey[300],
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
          const SizedBox(width: 6),
          Text(
            label,
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
