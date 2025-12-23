import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/station_detection_service.dart';
import '../services/theme_service.dart';

/// Widget that displays the current station detection status
class StationDetectionDisplay extends ConsumerWidget {
  const StationDetectionDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detectionAsync = ref.watch(stationDetectionAsyncProvider);

    return detectionAsync.when(
      data: (result) {
        if (result == null) {
          return _buildNoDataState(context);
        }
        return _buildDetectionResult(context, result);
      },
      loading: () => _buildLoadingState(context),
      error: (e, _) => _buildErrorState(context, e),
    );
  }

  Widget _buildNoDataState(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.neutralLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.location_searching, color: colors.neutral),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Waiting for location data...',
              style: TextStyle(color: colors.neutral),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.neutralLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Detecting station...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.errorBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Error: $error',
              style: TextStyle(color: colors.errorDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionResult(BuildContext context, StationDetectionResult result) {
    // Check if reached destination
    if (result.hasReachedDestination) {
      return _buildDestinationReached(context, result);
    }

    switch (result.proximity) {
      case StationProximity.atStation:
        return _buildAtStation(context, result);
      case StationProximity.betweenStations:
        return _buildBetweenStations(context, result);
      case StationProximity.beforeRoute:
        return _buildBeforeRoute(context, result);
      case StationProximity.afterRoute:
        return _buildAfterRoute(context, result);
      case StationProximity.unknown:
        return _buildUnknown(context, result);
    }
  }

  Widget _buildDestinationReached(BuildContext context, StationDetectionResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[400]!, Colors.green[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.celebration,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            '🎉 You\'ve Arrived!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.currentStation?.name ?? 'Destination',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtStation(BuildContext context, StationDetectionResult result) {
    final stationsAway = result.stationsToDestination;
    final isClose = stationsAway <= 2 && stationsAway > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isClose 
            ? Colors.orange[50] 
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isClose 
              ? Colors.orange 
              : Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isClose ? Colors.orange : Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'At Station',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      result.currentStation?.name ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStationsAwayBadge(stationsAway, isClose),
            ],
          ),
          if (result.nextStation != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.arrow_forward, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Next: ${result.nextStation!.name}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const Spacer(),
                if (result.distanceToNext != null)
                  Text(
                    _formatDistance(result.distanceToNext!),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBetweenStations(BuildContext context, StationDetectionResult result) {
    final stationsAway = result.stationsToDestination;
    final isClose = stationsAway <= 2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isClose ? Colors.orange[50] : Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isClose ? Colors.orange : Colors.blue,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isClose ? Colors.orange : Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_bus,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'In Transit',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${result.previousStation?.name ?? "?"} → ${result.nextStation?.name ?? "?"}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStationsAwayBadge(stationsAway, isClose),
            ],
          ),
          if (result.distanceToNext != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _calculateProgress(result),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation(
                isClose ? Colors.orange : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  result.previousStation?.name ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  '${_formatDistance(result.distanceToNext!)} to ${result.nextStation?.name}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBeforeRoute(BuildContext context, StationDetectionResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Approaching route start: ${result.nextStation?.name ?? "First station"}',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAfterRoute(BuildContext context, StationDetectionResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.red[600]),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'You may have passed your destination!',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnknown(BuildContext context, StationDetectionResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.location_searching, color: Colors.grey[600]),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Determining position...'),
          ),
        ],
      ),
    );
  }

  Widget _buildStationsAwayBadge(int stationsAway, bool isClose) {
    if (stationsAway <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'ARRIVED',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isClose ? Colors.orange : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$stationsAway ${stationsAway == 1 ? 'stop' : 'stops'} away',
        style: TextStyle(
          color: isClose ? Colors.white : Colors.grey[700],
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  double _calculateProgress(StationDetectionResult result) {
    // Rough estimate - this would need actual distance between stations
    // for accurate progress
    if (result.distanceToNext == null || result.distanceToCurrent == null) {
      return 0.5;
    }
    
    final total = result.distanceToNext! + result.distanceToCurrent!;
    if (total == 0) return 0.5;
    
    return result.distanceToCurrent! / total;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    }
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
}

/// Compact badge showing stations away from destination
class StationsAwayBadge extends ConsumerWidget {
  const StationsAwayBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detectionAsync = ref.watch(stationDetectionAsyncProvider);

    return detectionAsync.when(
      data: (result) {
        if (result == null) {
          return const SizedBox.shrink();
        }

        final stationsAway = result.stationsToDestination;
        final isClose = stationsAway <= 2 && stationsAway > 0;

        if (stationsAway <= 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'Arrived',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isClose ? Colors.orange : Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flag,
                size: 14,
                color: isClose ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                '$stationsAway away',
                style: TextStyle(
                  color: isClose ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
