import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/station.dart';
import '../services/station_provider.dart';
import '../services/location_tracking_service.dart';
import '../services/direction_inference_service.dart';
import '../services/station_progression_service.dart';
import '../services/eta_service.dart';
import '../services/alert_manager.dart';
import '../services/edge_case_handler.dart';
import '../widgets/live_location_display.dart';
import '../widgets/station_detection_display.dart';
import '../widgets/direction_inference_display.dart';
import '../widgets/station_progression_display.dart';
import '../widgets/eta_display.dart';
import '../widgets/live_status_display.dart';
import '../widgets/edge_case_warnings_display.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _journeyDetailsKey = GlobalKey();
  final GlobalKey _technicalInfoKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Start tracking when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize station progression
      await ref.read(stationProgressionProvider.notifier).initializeJourney();
      
      // Set up direction inference callback
      ref.read(directionInferenceCallbackProvider.notifier).state = (update) {
        ref.read(directionManagerProvider.notifier).updateWithLocation(update);
      };
      
      // Set up progression update callback
      ref.read(progressionUpdateCallbackProvider.notifier).state = (update) {
        ref.read(stationProgressionProvider.notifier).updateLocation(update);
      };
      
      // Set up ETA computation callback
      ref.read(etaUpdateCallbackProvider.notifier).state = (update) {
        ref.read(etaComputationProvider)(update);
      };
      
      // Reset alert state for new journey
      ref.read(alertManagerProvider.notifier).reset();
      
      // Reset edge case handler for new journey
      ref.read(edgeCaseHandlerProvider.notifier).reset();
      
      // Set up edge case monitoring callback
      ref.read(edgeCaseUpdateCallbackProvider.notifier).state = (update) {
        ref.read(edgeCaseHandlerProvider.notifier).processLocationUpdate(update);
      };
      
      ref.read(locationTrackingNotifierProvider.notifier).startTracking();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final direction = ref.watch(effectiveDirectionProvider) ?? ref.watch(selectedDirectionProvider);
    final destination = ref.watch(selectedDestinationProvider);
    final threshold = ref.watch(alertThresholdProvider);
    // Watch tracking state to rebuild on updates
    ref.watch(locationTrackingNotifierProvider);
    
    // Watch alert monitor to trigger notifications on progression changes
    ref.watch(alertMonitorProvider);

    if (destination == null || direction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text('No destination selected'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Tracking'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _showStopTrackingDialog(context),
        ),
        actions: [
          const StatusIndicatorChip(),
          const SizedBox(width: 8),
          const DirectionIndicatorBadge(),
          const SizedBox(width: 8),
          const GpsSignalIndicator(),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Edge case warnings banner (if any)
            const EdgeCaseWarningsDisplay(compact: true),
            
            // Compact Destination Header with ETA
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Heading to',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        Text(
                          destination.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        Row(
                          children: [
                            Icon(
                              direction == RouteDirection.northbound
                                  ? Icons.north
                                  : Icons.south,
                              size: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              direction.displayName,
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.notifications_active,
                              size: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$threshold stations alert',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Compact ETA badge
                  const ETADisplay(compact: true),
                ],
              ),
            ),

            // Main scrollable content
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Live Status Dashboard (current position, ETA, remaining)
                    const LiveStatusCard(),
                    const SizedBox(height: 12),
                    
                    // Upcoming Stations Preview
                    const UpcomingStationsCard(maxStations: 5),
                    const SizedBox(height: 12),
                    
                    // Speed Indicator
                    const SpeedIndicatorCard(),
                    const SizedBox(height: 12),
                    
                    // Collapsible detailed progression
                    ExpansionTile(
                      key: _journeyDetailsKey,
                      title: const Text('Journey Details'),
                      initiallyExpanded: false,
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      onExpansionChanged: (expanded) {
                        if (expanded) {
                          _scrollToWidget(_journeyDetailsKey);
                        }
                      },
                      children: const [
                        SizedBox(height: 8),
                        StationProgressionDisplay(),
                        SizedBox(height: 8),
                        StationDetectionDisplay(),
                      ],
                    ),
                    
                    // Collapsible technical details
                    ExpansionTile(
                      key: _technicalInfoKey,
                      title: const Text('Technical Info'),
                      initiallyExpanded: false,
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      onExpansionChanged: (expanded) {
                        if (expanded) {
                          _scrollToWidget(_technicalInfoKey);
                        }
                      },
                      children: const [
                        SizedBox(height: 8),
                        ETADisplay(showDetails: true),
                        SizedBox(height: 8),
                        DirectionInferenceDisplay(showDetails: false),
                        SizedBox(height: 8),
                        LiveLocationDisplay(showDetails: false),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Stop Tracking Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: () => _showStopTrackingDialog(context),
                icon: const Icon(Icons.stop),
                label: const Text('Stop Tracking'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStopTrackingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Tracking?'),
        content: const Text(
          'Are you sure you want to stop tracking? You will no longer receive station alerts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(locationTrackingNotifierProvider.notifier).stopTracking();
              ref.read(stationProgressionProvider.notifier).reset();
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  /// Scroll to make a widget visible after expansion
  void _scrollToWidget(GlobalKey key) {
    // Wait for expansion animation to complete (ExpansionTile animation is ~200ms)
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final keyContext = key.currentContext;
      if (keyContext != null && keyContext.mounted) {
        Scrollable.ensureVisible(
          keyContext,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }
}
