// lib/services/auto_sync_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sync_service.dart';

class AutoSyncService {
  static final AutoSyncService _instance = AutoSyncService._internal();
  factory AutoSyncService() => _instance;
  AutoSyncService._internal();

  final SyncService _syncService = SyncService();
  Timer? _periodicSyncTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isAutoSyncEnabled = true;
  bool _syncOnDataChange = true;
  bool _syncOnNetworkChange = true;
  int _syncIntervalMinutes = 30; // Default 30 minutes
  DateTime? _lastAutoSyncAttempt;
  bool _isInitialized = false;

  // Stream controllers for sync status
  final StreamController<SyncStatus> _syncStatusController =
      StreamController<SyncStatus>.broadcast();
  final StreamController<bool> _networkStatusController =
      StreamController<bool>.broadcast();

  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  Stream<bool> get networkStatusStream => _networkStatusController.stream;

  // Getters
  bool get isAutoSyncEnabled => _isAutoSyncEnabled;
  bool get syncOnDataChange => _syncOnDataChange;
  bool get syncOnNetworkChange => _syncOnNetworkChange;
  int get syncIntervalMinutes => _syncIntervalMinutes;
  DateTime? get lastAutoSyncAttempt => _lastAutoSyncAttempt;

  /// Initialize the auto sync service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadSettings();
      await _setupConnectivityListener();
      if (_isAutoSyncEnabled) {
        await _startPeriodicSync();
      }
      _isInitialized = true;
      print("AutoSyncService: Initialized successfully");
    } catch (e) {
      print("AutoSyncService: Initialization error: $e");
    }
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAutoSyncEnabled = prefs.getBool('autoSyncEnabled') ?? true;
      _syncOnDataChange = prefs.getBool('syncOnDataChange') ?? true;
      _syncOnNetworkChange = prefs.getBool('syncOnNetworkChange') ?? true;
      _syncIntervalMinutes = prefs.getInt('syncIntervalMinutes') ?? 30;

      final lastSyncString = prefs.getString('lastAutoSyncAttempt');
      if (lastSyncString != null) {
        _lastAutoSyncAttempt = DateTime.tryParse(lastSyncString);
      }
    } catch (e) {
      print("AutoSyncService: Error loading settings: $e");
    }
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('autoSyncEnabled', _isAutoSyncEnabled);
      await prefs.setBool('syncOnDataChange', _syncOnDataChange);
      await prefs.setBool('syncOnNetworkChange', _syncOnNetworkChange);
      await prefs.setInt('syncIntervalMinutes', _syncIntervalMinutes);

      if (_lastAutoSyncAttempt != null) {
        await prefs.setString(
            'lastAutoSyncAttempt', _lastAutoSyncAttempt!.toIso8601String());
      }
    } catch (e) {
      print("AutoSyncService: Error saving settings: $e");
    }
  }

  /// Setup connectivity listener for network changes
  Future<void> _setupConnectivityListener() async {
    try {
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        (ConnectivityResult result) async {
          final isConnected = result != ConnectivityResult.none;
          _networkStatusController.add(isConnected);

          if (isConnected && _syncOnNetworkChange && _isAutoSyncEnabled) {
            // Wait a bit for network to stabilize
            await Future.delayed(const Duration(seconds: 3));
            await _performAutoSync(SyncTrigger.networkChange);
          }
        },
      );
    } catch (e) {
      print("AutoSyncService: Error setting up connectivity listener: $e");
    }
  }

  /// Start periodic sync timer
  Future<void> _startPeriodicSync() async {
    _stopPeriodicSync();

    if (_syncIntervalMinutes > 0) {
      _periodicSyncTimer = Timer.periodic(
        Duration(minutes: _syncIntervalMinutes),
        (_) => _performAutoSync(SyncTrigger.periodic),
      );
      print(
          "AutoSyncService: Periodic sync started (${_syncIntervalMinutes}min intervals)");
    }
  }

  /// Stop periodic sync timer
  void _stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }

  /// Check if device has internet connectivity
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Perform auto sync with specified trigger
  Future<void> _performAutoSync(SyncTrigger trigger) async {
    if (!_isAutoSyncEnabled) return;

    // Check if we're not syncing too frequently
    if (_lastAutoSyncAttempt != null) {
      final timeSinceLastSync =
          DateTime.now().difference(_lastAutoSyncAttempt!);
      if (timeSinceLastSync.inMinutes < 2) {
        print("AutoSyncService: Skipping sync - too soon since last attempt");
        return;
      }
    }

    // Check internet connectivity
    if (!await _hasInternetConnection()) {
      print("AutoSyncService: No internet connection available");
      _syncStatusController.add(SyncStatus.noInternet);
      return;
    }

    _lastAutoSyncAttempt = DateTime.now();
    await _saveSettings();

    try {
      _syncStatusController.add(SyncStatus.syncing);
      print("AutoSyncService: Starting auto sync (trigger: ${trigger.name})");

      final success = await _syncService.performSync();

      if (success) {
        _syncStatusController.add(SyncStatus.success);
        print("AutoSyncService: Auto sync completed successfully");
      } else {
        _syncStatusController.add(SyncStatus.failed);
        print("AutoSyncService: Auto sync failed");
      }
    } catch (e) {
      _syncStatusController.add(SyncStatus.failed);
      print("AutoSyncService: Auto sync error: $e");
    }
  }

  /// Trigger sync when data changes
  Future<void> triggerSyncOnDataChange() async {
    if (_syncOnDataChange && _isAutoSyncEnabled) {
      // Debounce data change syncs to avoid too many calls
      await Future.delayed(const Duration(seconds: 5));
      await _performAutoSync(SyncTrigger.dataChange);
    }
  }

  /// Manual sync trigger
  Future<bool> triggerManualSync() async {
    try {
      _syncStatusController.add(SyncStatus.syncing);
      final success = await _syncService.performSync();

      if (success) {
        _syncStatusController.add(SyncStatus.success);
      } else {
        _syncStatusController.add(SyncStatus.failed);
      }

      return success;
    } catch (e) {
      _syncStatusController.add(SyncStatus.failed);
      print("AutoSyncService: Manual sync error: $e");
      return false;
    }
  }

  /// Update auto sync settings
  Future<void> updateSettings({
    bool? autoSyncEnabled,
    bool? syncOnDataChange,
    bool? syncOnNetworkChange,
    int? syncIntervalMinutes,
  }) async {
    bool needsTimerRestart = false;

    if (autoSyncEnabled != null && autoSyncEnabled != _isAutoSyncEnabled) {
      _isAutoSyncEnabled = autoSyncEnabled;
      needsTimerRestart = true;
    }

    if (syncOnDataChange != null) {
      _syncOnDataChange = syncOnDataChange;
    }

    if (syncOnNetworkChange != null) {
      _syncOnNetworkChange = syncOnNetworkChange;
    }

    if (syncIntervalMinutes != null &&
        syncIntervalMinutes != _syncIntervalMinutes) {
      _syncIntervalMinutes = syncIntervalMinutes;
      needsTimerRestart = true;
    }

    await _saveSettings();

    if (needsTimerRestart) {
      if (_isAutoSyncEnabled) {
        await _startPeriodicSync();
      } else {
        _stopPeriodicSync();
      }
    }
  }

  /// Get sync statistics
  Future<SyncStatistics> getSyncStatistics() async {
    try {
      final lastSyncTime = await _syncService.getLastSyncTime();
      final prefs = await SharedPreferences.getInstance();

      return SyncStatistics(
        lastSuccessfulSync: lastSyncTime,
        lastAutoSyncAttempt: _lastAutoSyncAttempt,
        autoSyncEnabled: _isAutoSyncEnabled,
        syncIntervalMinutes: _syncIntervalMinutes,
        totalSyncAttempts: prefs.getInt('totalSyncAttempts') ?? 0,
        successfulSyncs: prefs.getInt('successfulSyncs') ?? 0,
      );
    } catch (e) {
      print("AutoSyncService: Error getting sync statistics: $e");
      return SyncStatistics.empty();
    }
  }

  /// Dispose resources
  void dispose() {
    _stopPeriodicSync();
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
    _networkStatusController.close();
    _isInitialized = false;
  }
}

enum SyncTrigger {
  manual,
  periodic,
  dataChange,
  networkChange,
  appStart,
}

enum SyncStatus {
  idle,
  syncing,
  success,
  failed,
  noInternet,
  conflict,
}

class SyncStatistics {
  final DateTime? lastSuccessfulSync;
  final DateTime? lastAutoSyncAttempt;
  final bool autoSyncEnabled;
  final int syncIntervalMinutes;
  final int totalSyncAttempts;
  final int successfulSyncs;

  SyncStatistics({
    this.lastSuccessfulSync,
    this.lastAutoSyncAttempt,
    required this.autoSyncEnabled,
    required this.syncIntervalMinutes,
    required this.totalSyncAttempts,
    required this.successfulSyncs,
  });

  factory SyncStatistics.empty() {
    return SyncStatistics(
      autoSyncEnabled: true,
      syncIntervalMinutes: 30,
      totalSyncAttempts: 0,
      successfulSyncs: 0,
    );
  }

  double get successRate {
    if (totalSyncAttempts == 0) return 0.0;
    return successfulSyncs / totalSyncAttempts;
  }
}
