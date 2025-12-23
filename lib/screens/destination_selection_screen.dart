import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/station.dart';
import '../services/station_provider.dart';
import '../widgets/alert_threshold_selector.dart';
import 'tracking_screen.dart';

class DestinationSelectionScreen extends ConsumerWidget {
  const DestinationSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direction = ref.watch(selectedDirectionProvider);
    final stationsAsync = ref.watch(stationsByDirectionProvider);
    final selectedDestination = ref.watch(selectedDestinationProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Select Destination'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Direction Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(
                  direction == RouteDirection.northbound
                      ? Icons.north
                      : Icons.south,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      direction?.displayName ?? 'Unknown',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      direction?.description ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Station List
          Expanded(
            child: stationsAsync.when(
              data: (stations) {
                if (stations.isEmpty) {
                  return const Center(
                    child: Text('No stations available'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: stations.length,
                  itemBuilder: (context, index) {
                    final station = stations[index];
                    final isSelected = selectedDestination?.id == station.id;
                    final order = station.getOrder(direction!);

                    return _StationListItem(
                      station: station,
                      order: order,
                      isSelected: isSelected,
                      isFirst: index == 0,
                      isLast: index == stations.length - 1,
                      onTap: () {
                        ref.read(selectedDestinationProvider.notifier).state =
                            station;
                      },
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text('Error loading stations: $error'),
                  ],
                ),
              ),
            ),
          ),
          
          // Alert Threshold Section (shown when destination is selected)
          if (selectedDestination != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: const AlertThresholdSelector(),
            ),
          
          // Bottom Action Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: selectedDestination != null
                    ? () {
                        // Navigate to tracking screen
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const TrackingScreen(),
                          ),
                        );
                      }
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: Text(
                  selectedDestination != null
                      ? 'Start Tracking to ${selectedDestination.name}'
                      : 'Select a destination',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StationListItem extends StatelessWidget {
  final Station station;
  final int order;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _StationListItem({
    required this.station,
    required this.order,
    required this.isSelected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
            : null,
        child: Row(
          children: [
            // Timeline indicator
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  // Top line
                  Container(
                    width: 2,
                    height: 12,
                    color: isFirst ? Colors.transparent : Colors.grey[300],
                  ),
                  // Circle
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : station.isTerminal
                              ? Colors.deepPurple[200]
                              : Colors.grey[300],
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : station.isTerminal
                                ? Colors.deepPurple
                                : Colors.grey[400]!,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$order',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  // Bottom line
                  Container(
                    width: 2,
                    height: 12,
                    color: isLast ? Colors.transparent : Colors.grey[300],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            
            // Station info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          station.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                        ),
                      ),
                      if (station.isTerminal)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Terminal',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.deepPurple[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    station.fullName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  if (station.landmarks.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      station.landmarks.take(2).join(' • '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            
            // Selection indicator
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
