import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_service.dart';
import 'station_provider.dart';
import 'station_progression_service.dart';
import 'eta_service.dart';

/// Tracks which alerts have been triggered to prevent duplicates
class AlertState {
  final Set<int> triggeredThresholds;
  final bool arrivalNotified;
  final DateTime? lastAlertTime;

  const AlertState({
    this.triggeredThresholds = const {},
    this.arrivalNotified = false,
    this.lastAlertTime,
  });

  AlertState copyWith({
    Set<int>? triggeredThresholds,
    bool? arrivalNotified,
    DateTime? lastAlertTime,
  }) {
    return AlertState(
      triggeredThresholds: triggeredThresholds ?? this.triggeredThresholds,
      arrivalNotified: arrivalNotified ?? this.arrivalNotified,
      lastAlertTime: lastAlertTime ?? this.lastAlertTime,
    );
  }

  /// Check if an alert for this threshold was already triggered
  bool hasTriggered(int threshold) => triggeredThresholds.contains(threshold);

  @override
  String toString() => 'AlertState(triggered: $triggeredThresholds, arrived: $arrivalNotified)';
}

/// Manages alert triggering logic
class AlertManager extends StateNotifier<AlertState> {
  final NotificationService _notificationService;
  final Ref _ref;

  AlertManager(this._notificationService, this._ref) : super(const AlertState());

  /// Check and trigger alerts based on current state
  Future<void> checkAndTriggerAlerts() async {
    final progression = _ref.read(stationProgressionProvider);
    final threshold = _ref.read(alertThresholdProvider);
    final remaining = progression.remainingCount;
    final destination = progression.destination;
    final hasArrived = progression.hasArrived;

    if (destination == null) return;

    debugPrint('AlertManager: remaining=$remaining, threshold=$threshold, hasArrived=$hasArrived');

    // Check for arrival first
    if (hasArrived && !state.arrivalNotified) {
      debugPrint('AlertManager: Triggering arrival notification');
      await _notificationService.showArrivalNotification(
        stationName: destination.name,
      );
      state = state.copyWith(
        arrivalNotified: true,
        lastAlertTime: DateTime.now(),
      );
      return;
    }

    // Check threshold alerts (trigger at threshold and below)
    // But only trigger ONCE per threshold level
    if (remaining <= threshold && remaining > 0) {
      if (!state.hasTriggered(remaining)) {
        debugPrint('AlertManager: Triggering alert for $remaining stations remaining');
        
        // Get ETA if available
        final etaResult = _ref.read(etaResultProvider);
        String? etaString;
        if (etaResult.etaToDestination != null) {
          etaString = etaResult.etaToDestFormatted;
        }

        await _notificationService.showStationAlert(
          stationName: destination.name,
          stationsAway: remaining,
          eta: etaString,
        );

        // Mark this threshold as triggered
        final newTriggered = Set<int>.from(state.triggeredThresholds)..add(remaining);
        state = state.copyWith(
          triggeredThresholds: newTriggered,
          lastAlertTime: DateTime.now(),
        );
      }
    }
  }

  /// Reset alert state for a new journey
  void reset() {
    debugPrint('AlertManager: Resetting alert state');
    state = const AlertState();
  }

  /// Manually trigger a test alert
  Future<void> triggerTestAlert() async {
    final destination = _ref.read(selectedDestinationProvider);
    final remaining = _ref.read(stationsRemainingProvider);
    
    await _notificationService.showStationAlert(
      stationName: destination?.name ?? 'Test Station',
      stationsAway: remaining > 0 ? remaining : 2,
    );
  }
}

// ============ PROVIDERS ============

/// Provider for alert manager
final alertManagerProvider = StateNotifierProvider<AlertManager, AlertState>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  return AlertManager(notificationService, ref);
});

/// Provider that monitors progression and triggers alerts automatically
/// This should be watched from the tracking screen to activate monitoring
final alertMonitorProvider = Provider<void>((ref) {
  // Watch progression changes
  final progression = ref.watch(stationProgressionProvider);
  final alertManager = ref.read(alertManagerProvider.notifier);
  
  // Check alerts whenever progression updates
  if (progression.stationRecords.isNotEmpty) {
    // Use Future.microtask to avoid triggering during build
    Future.microtask(() {
      alertManager.checkAndTriggerAlerts();
    });
  }
  
  return;
});

/// Provider to check if alerts are enabled (permission granted)
final alertsEnabledProvider = FutureProvider<bool>((ref) async {
  final notificationService = ref.watch(notificationServiceProvider);
  return await notificationService.areNotificationsEnabled();
});
