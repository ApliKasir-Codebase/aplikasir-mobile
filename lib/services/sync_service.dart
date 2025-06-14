// lib/services/sync_service.dart
import 'dart:convert';
import 'package:flutter/material.dart'; // Untuk BuildContext
import 'package:shared_preferences/shared_preferences.dart';
import 'api_services.dart'; // Pastikan path ini benar
import '../helper/db_helper.dart';
// Impor model yang sudah diupdate
import '../model/product_model.dart';
import '../model/customer_model.dart';
import '../model/transaction_model.dart';

class SyncService {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static bool _isSyncing = false; // Static flag

  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampString = prefs.getString('lastSyncTimestamp');
      return timestampString != null
          ? DateTime.tryParse(timestampString)
          : null;
    } catch (e) {
      print("SyncService Error getting last sync time: $e");
      return null;
    }
  }

  Future<void> setLastSyncTime(DateTime timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastSyncTimestamp', timestamp.toIso8601String());
      print(
          "SyncService: New Last Sync Time saved: ${timestamp.toIso8601String()}");
    } catch (e) {
      print("SyncService Error setting last sync time: $e");
    }
  }

  /// Update sync statistics
  Future<void> _updateSyncStatistics(bool success) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final totalAttempts = prefs.getInt('totalSyncAttempts') ?? 0;
      final successfulSyncs = prefs.getInt('successfulSyncs') ?? 0;

      await prefs.setInt('totalSyncAttempts', totalAttempts + 1);
      if (success) {
        await prefs.setInt('successfulSyncs', successfulSyncs + 1);
      }
    } catch (e) {
      print("SyncService Error updating statistics: $e");
    }
  }

  Future<Map<String, dynamic>> _getLocalChanges(DateTime? lastSyncTime) async {
    final Map<String, dynamic> changes = {
      'products': {
        'new': [],
        'updated': [],
        'deleted': [],
      },
      'customers': {
        'new': [],
        'updated': [],
        'deleted': [],
      },
      'transactions': {
        'new': [],
        'updated': [],
        'deleted': [],
      },
    };

    try {
      // --- Products ---
      final productsToSync = await _dbHelper.getProductsForSync(lastSyncTime);
      for (var p in productsToSync) {
        final map = p.toMap(); // Gunakan toMap dasar
        map['local_id'] = p.id; // ID lokal penting untuk markSyncedItems
        map['created_at'] =
            p.createdAt?.toIso8601String(); // Convert to ISO8601 string
        map['updated_at'] =
            p.updatedAt?.toIso8601String(); // Convert to ISO8601 string
        map['is_deleted'] = p.isDeleted; // Kirim status delete

        if (p.syncStatus == 'new')
          changes['products']!['new']!.add(map);
        else if (p.syncStatus == 'updated')
          changes['products']!['updated']!.add(map);
        else if (p.syncStatus == 'deleted' && p.id != null)
          changes['products']!['deleted']!.add(p.id!);
      }

      // --- Customers ---
      final customersToSync = await _dbHelper.getCustomersForSync(lastSyncTime);
      for (var c in customersToSync) {
        final map = c.toMap();
        map['local_id'] = c.id;
        map['created_at'] =
            c.createdAt.toIso8601String(); // Pastikan format ISO
        map['updated_at'] = c.updatedAt?.toIso8601String(); // Handle nullable
        map['is_deleted'] = c.isDeleted;

        if (c.syncStatus == 'new')
          changes['customers']!['new']!.add(map);
        else if (c.syncStatus == 'updated')
          changes['customers']!['updated']!.add(map);
        else if (c.syncStatus == 'deleted' && c.id != null)
          changes['customers']!['deleted']!.add(c.id!);
      }

      // --- Transactions ---
      final transactionsToSync =
          await _dbHelper.getTransactionsForSync(lastSyncTime);
      for (var t in transactionsToSync) {
        final map = t.toMap();
        map['local_id'] = t.id;
        map['created_at'] = t.createdAt?.toIso8601String();
        map['updated_at'] = t.updatedAt?.toIso8601String();
        map['detail_items'] = jsonEncode(t.detailItems); // Encode detail items
        map['is_deleted'] = t.isDeleted;

        if (t.syncStatus == 'new')
          changes['transactions']!['new']!.add(map);
        // else if (t.syncStatus == 'updated') changes['updatedTransactions']!.add(map); // Jika ada update transaksi
        else if (t.syncStatus == 'deleted' && t.id != null)
          changes['transactions']!['deleted']!.add(t.id!);
      }

      print("SyncService: Local changes prepared: "
          "P(N${changes['products']!['new']?.length}/U${changes['products']!['updated']?.length}/D${changes['products']!['deleted']?.length}), "
          "C(N${changes['customers']!['new']?.length}/U${changes['customers']!['updated']?.length}/D${changes['customers']!['deleted']?.length}), "
          "T(N${changes['transactions']!['new']?.length}/D${changes['transactions']!['deleted']?.length})");
    } catch (e) {
      print("SyncService Error preparing local changes: $e");
      // Mengembalikan map kosong jika error agar sync tetap bisa mencoba download
    }
    return changes;
  }

  Future<void> _applyServerChanges(Map<String, dynamic>? serverChanges) async {
    if (serverChanges == null || serverChanges.isEmpty) {
      print("SyncService: No server changes to apply.");
      return;
    }
    print("SyncService: Applying server changes...");
    final db = await _dbHelper.database;

    try {
      await db.transaction((txn) async {
        int appliedNewProd = 0, appliedUpdProd = 0, appliedDelProd = 0;
        int appliedNewCust = 0, appliedUpdCust = 0, appliedDelCust = 0;
        int appliedNewTx = 0, appliedDelTx = 0;

        // --- Products ---
        final products = serverChanges['products'] ?? {};

        for (var pData in products['new'] ?? []) {
          try {
            await _dbHelper.insertOrReplaceProductFromApi(
                txn, Product.fromMap(pData));
            appliedNewProd++;
          } catch (e) {
            print(
                " SyncService Error applying new product ${pData['id'] ?? pData['server_id']}: $e");
          }
        }

        for (var pData in products['updated'] ?? []) {
          try {
            await _dbHelper.insertOrReplaceProductFromApi(
                txn, Product.fromMap(pData));
            appliedUpdProd++;
          } catch (e) {
            print(
                " SyncService Error applying updated product ${pData['id'] ?? pData['server_id']}: $e");
          }
        }

        for (var serverIdDynamic in products['deleted'] ?? []) {
          try {
            final int serverId = serverIdDynamic is int
                ? serverIdDynamic
                : int.parse(serverIdDynamic.toString());
            await _dbHelper.deleteProductLocalFromServer(txn, serverId);
            appliedDelProd++;
          } catch (e) {
            print(
                " SyncService Error applying deleted product serverId $serverIdDynamic: $e");
          }
        }

        // --- Customers ---
        final customers = serverChanges['customers'] ?? {};

        for (var cData in customers['new'] ?? []) {
          try {
            await _dbHelper.insertOrReplaceCustomerFromApi(
                txn, Customer.fromMap(cData));
            appliedNewCust++;
          } catch (e) {
            print(
                " SyncService Error applying new customer ${cData['id'] ?? cData['server_id']}: $e");
          }
        }

        for (var cData in customers['updated'] ?? []) {
          try {
            await _dbHelper.insertOrReplaceCustomerFromApi(
                txn, Customer.fromMap(cData));
            appliedUpdCust++;
          } catch (e) {
            print(
                " SyncService Error applying updated customer ${cData['id'] ?? cData['server_id']}: $e");
          }
        }

        for (var serverIdDynamic in customers['deleted'] ?? []) {
          try {
            final int serverId = serverIdDynamic is int
                ? serverIdDynamic
                : int.parse(serverIdDynamic.toString());
            await _dbHelper.deleteCustomerLocalFromServer(txn, serverId);
            appliedDelCust++;
          } catch (e) {
            print(
                " SyncService Error applying deleted customer serverId $serverIdDynamic: $e");
          }
        }

        // --- Transactions ---
        final transactions = serverChanges['transactions'] ?? {};

        for (var tData in transactions['new'] ?? []) {
          try {
            if (tData['detail_items'] is String) {
              try {
                tData['detail_items'] = jsonDecode(tData['detail_items']);
              } catch (_) {
                tData['detail_items'] = [];
              }
            } else if (tData['detail_items'] is! List) {
              tData['detail_items'] = [];
            }
            await _dbHelper.insertOrReplaceTransactionFromApi(
                txn, TransactionModel.fromMap(tData));
            appliedNewTx++;
          } catch (e) {
            print(
                " SyncService Error applying new transaction ${tData['id'] ?? tData['server_id']}: $e");
          }
        }

        // Handle updated/deleted transactions jika ada
        for (var serverIdDynamic in transactions['deleted'] ?? []) {
          try {
            final int serverId = serverIdDynamic is int
                ? serverIdDynamic
                : int.parse(serverIdDynamic.toString());
            await _dbHelper.deleteTransactionLocalFromServer(txn, serverId);
            appliedDelTx++;
          } catch (e) {
            print(
                " SyncService Error applying deleted transaction serverId $serverIdDynamic: $e");
          }
        }

        print("SyncService: Server changes applied summary: "
            "Prod(N$appliedNewProd/U$appliedUpdProd/D$appliedDelProd), "
            "Cust(N$appliedNewCust/U$appliedUpdCust/D$appliedDelCust), "
            "Tx(N$appliedNewTx/D$appliedDelTx)");
      });
      print(
          "SyncService: Database transaction for applying server changes committed.");
    } catch (e) {
      print(
          "SyncService Error during DB transaction for applying server changes: $e");
      throw Exception("Failed to apply server changes locally: $e");
    }
  }

  Future<bool> performSync() async {
    if (_isSyncing) {
      print("SyncService: Sync already in progress.");
      return false;
    }
    _isSyncing = true;
    print("SyncService: Starting synchronization...");
    bool success = false;

    try {
      final lastSync = await getLastSyncTime();
      print(
          "SyncService: Client Last Sync Time: ${lastSync?.toIso8601String()}");

      final localChanges = await _getLocalChanges(lastSync);

      // Panggil API
      final syncResponse = await _apiService.synchronize(
          lastSync?.toIso8601String(), localChanges);

      // Proses response server
      final serverChanges = syncResponse['serverChanges'];
      final newServerTimestampString = syncResponse['serverSyncTime'];

      if (newServerTimestampString == null) {
        throw Exception(
            "SyncService Error: Server did not return a new sync timestamp.");
      }
      final newServerTimestamp = DateTime.parse(newServerTimestampString);

      // Terapkan perubahan server ke DB lokal
      if (serverChanges != null && serverChanges is Map<String, dynamic>) {
        await _applyServerChanges(serverChanges);
      } else {
        print("SyncService: No valid server changes received in response.");
      }

      // Tandai item lokal yang DIKIRIM sebagai synced/deleted
      await _dbHelper.markSyncedItems(localChanges);

      // Simpan timestamp sync terakhir yang sukses
      await setLastSyncTime(newServerTimestamp);

      print(
          "SyncService: Synchronization finished successfully at ${newServerTimestamp.toIso8601String()}");
      success = true;
      await _updateSyncStatistics(true);
    } catch (e) {
      print("SyncService: Synchronization failed: $e");
      if (e is Exception) print("SyncService Error details: ${e.toString()}");
      success = false;
      await _updateSyncStatistics(false);
    } finally {
      _isSyncing = false;
      print(
          "SyncService: Sync process finished. Result: ${success ? 'Success' : 'Failure'}");
    }
    return success;
  }

  Future<void> triggerSync(
      {bool showSnackbar = false, BuildContext? context}) async {
    if (showSnackbar && (context == null || !context.mounted)) {
      print("SyncService Warning: Cannot show snackbar, context is invalid.");
      showSnackbar = false;
    }

    final result = await performSync(); // Tunggu hasilnya

    // Tampilkan snackbar HANYA jika diminta dan context valid
    if (showSnackbar && context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result
            ? 'Sinkronisasi data berhasil!'
            : 'Sinkronisasi data gagal. Coba lagi nanti.'),
        backgroundColor: result ? Colors.green.shade600 : Colors.redAccent,
        duration: Duration(seconds: result ? 2 : 4), // Lebih lama jika gagal
      ));
    }
  }

  /// Resolve conflicts manually with user selections
  Future<bool> resolveConflicts(List<Map<String, dynamic>> conflicts) async {
    try {
      print("SyncService: Resolving ${conflicts.length} conflicts manually");

      final response =
          await _apiService.synchronizeConflictResolution(conflicts);

      if (response['success'] == true) {
        print(
            "SyncService: Successfully resolved ${response['resolved']} conflicts");

        // Update sync statistics
        await _updateSyncStatistics(true);

        return true;
      } else {
        print(
            "SyncService: Failed to resolve conflicts: ${response['errors']}");
        return false;
      }
    } catch (e) {
      print("SyncService Error resolving conflicts: $e");
      return false;
    }
  }

  /// Get detailed sync metrics from server
  Future<Map<String, dynamic>?> getSyncMetrics({int days = 7}) async {
    try {
      final response = await _apiService.getSyncMetrics(days);

      if (response['success'] == true) {
        return response['metrics'];
      } else {
        print("SyncService: Failed to get sync metrics: ${response['error']}");
        return null;
      }
    } catch (e) {
      print("SyncService Error getting sync metrics: $e");
      return null;
    }
  }

  // Enhanced sync functions with better error handling and progress tracking

  /// Force full sync - re-download all data from server
  Future<bool> performFullSync() async {
    if (_isSyncing) {
      print("SyncService: Sync already in progress.");
      return false;
    }
    _isSyncing = true;
    print("SyncService: Starting FULL synchronization...");
    bool success = false;

    try {
      // Reset last sync time to force full download
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lastSyncTimestamp');

      // Perform normal sync which will now download everything
      success = await performSync();
    } catch (e) {
      print("SyncService: Full synchronization failed: $e");
      success = false;
    } finally {
      _isSyncing = false;
    }
    return success;
  }

  /// Sync only local changes to server (upload only)
  Future<bool> performUploadOnlySync() async {
    if (_isSyncing) {
      print("SyncService: Sync already in progress.");
      return false;
    }
    _isSyncing = true;
    print("SyncService: Starting UPLOAD-ONLY synchronization...");
    bool success = false;

    try {
      final lastSync = await getLastSyncTime();
      final localChanges = await _getLocalChanges(lastSync);

      // Check if there are any local changes to upload
      final hasChanges = _hasLocalChanges(localChanges);
      if (!hasChanges) {
        print("SyncService: No local changes to upload.");
        success = true;
        return success;
      }

      // Call API with upload-only flag
      final syncResponse = await _apiService.synchronizeUploadOnly(
          lastSync?.toIso8601String(), localChanges);

      if (syncResponse['success'] == true) {
        // Mark uploaded items as synced
        await _dbHelper.markSyncedItems(localChanges);
        success = true;
        print("SyncService: Upload-only sync completed successfully.");
      }
    } catch (e) {
      print("SyncService: Upload-only synchronization failed: $e");
      success = false;
    } finally {
      _isSyncing = false;
    }
    return success;
  }

  /// Sync only server changes to local (download only)
  Future<bool> performDownloadOnlySync() async {
    if (_isSyncing) {
      print("SyncService: Sync already in progress.");
      return false;
    }
    _isSyncing = true;
    print("SyncService: Starting DOWNLOAD-ONLY synchronization...");
    bool success = false;

    try {
      final lastSync = await getLastSyncTime();

      // Call API with download-only flag (empty local changes)
      final emptyChanges = {
        'products': {'new': [], 'updated': [], 'deleted': []},
        'customers': {'new': [], 'updated': [], 'deleted': []},
        'transactions': {'new': [], 'updated': [], 'deleted': []},
      };

      final syncResponse = await _apiService.synchronizeDownloadOnly(
          lastSync?.toIso8601String(), emptyChanges);

      // Process server changes
      final serverChanges = syncResponse['serverChanges'];
      final newServerTimestampString = syncResponse['serverSyncTime'];

      if (newServerTimestampString == null) {
        throw Exception(
            "SyncService Error: Server did not return a new sync timestamp.");
      }
      final newServerTimestamp = DateTime.parse(newServerTimestampString);

      // Apply server changes to local DB
      if (serverChanges != null && serverChanges is Map<String, dynamic>) {
        await _applyServerChanges(serverChanges);
        await setLastSyncTime(newServerTimestamp);
        success = true;
        print("SyncService: Download-only sync completed successfully.");
      } else {
        print("SyncService: No valid server changes received in response.");
        success = true; // No changes is still success
      }
    } catch (e) {
      print("SyncService: Download-only synchronization failed: $e");
      success = false;
    } finally {
      _isSyncing = false;
    }
    return success;
  }

  /// Sync with custom direction control
  Future<bool> performDirectionalSync({
    bool uploadEnabled = true,
    bool downloadEnabled = true,
    List<String> dataTypes = const ['products', 'customers', 'transactions'],
  }) async {
    if (_isSyncing) {
      print("SyncService: Sync already in progress.");
      return false;
    }
    _isSyncing = true;
    print(
        "SyncService: Starting DIRECTIONAL synchronization (Upload: $uploadEnabled, Download: $downloadEnabled)...");
    bool success = false;

    try {
      final lastSync = await getLastSyncTime();
      Map<String, dynamic> localChanges = {};

      // Prepare local changes only if upload is enabled
      if (uploadEnabled) {
        localChanges = await _getLocalChanges(lastSync);
        // Filter by requested data types
        localChanges = _filterChangesByDataTypes(localChanges, dataTypes);
      } else {
        // Send empty changes
        localChanges = {
          'products': {'new': [], 'updated': [], 'deleted': []},
          'customers': {'new': [], 'updated': [], 'deleted': []},
          'transactions': {'new': [], 'updated': [], 'deleted': []},
        };
      }

      // Call appropriate API endpoint
      Map<String, dynamic> syncResponse;
      if (uploadEnabled && downloadEnabled) {
        syncResponse = await _apiService.synchronize(
            lastSync?.toIso8601String(), localChanges);
      } else if (uploadEnabled && !downloadEnabled) {
        syncResponse = await _apiService.synchronizeUploadOnly(
            lastSync?.toIso8601String(), localChanges);
      } else if (!uploadEnabled && downloadEnabled) {
        syncResponse = await _apiService.synchronizeDownloadOnly(
            lastSync?.toIso8601String(), localChanges);
      } else {
        throw Exception("Both upload and download are disabled");
      }

      // Process response
      final serverChanges = syncResponse['serverChanges'];
      final newServerTimestampString = syncResponse['serverSyncTime'];

      if (newServerTimestampString == null) {
        throw Exception(
            "SyncService Error: Server did not return a new sync timestamp.");
      }
      final newServerTimestamp = DateTime.parse(newServerTimestampString);

      // Apply server changes if download is enabled
      if (downloadEnabled &&
          serverChanges != null &&
          serverChanges is Map<String, dynamic>) {
        final filteredServerChanges =
            _filterChangesByDataTypes(serverChanges, dataTypes);
        await _applyServerChanges(filteredServerChanges);
      }

      // Mark uploaded items as synced if upload was enabled
      if (uploadEnabled && _hasLocalChanges(localChanges)) {
        await _dbHelper.markSyncedItems(localChanges);
      }

      await setLastSyncTime(newServerTimestamp);
      success = true;
      print("SyncService: Directional sync completed successfully.");
    } catch (e) {
      print("SyncService: Directional synchronization failed: $e");
      success = false;
    } finally {
      _isSyncing = false;
    }
    return success;
  }

  /// Filter changes by data types
  Map<String, dynamic> _filterChangesByDataTypes(
      Map<String, dynamic> changes, List<String> dataTypes) {
    final filtered = <String, dynamic>{};

    for (String dataType in dataTypes) {
      if (changes.containsKey(dataType)) {
        filtered[dataType] = changes[dataType];
      }
    }

    return filtered;
  }

  /// Check if there are any local changes to sync
  bool _hasLocalChanges(Map<String, dynamic> changes) {
    final products = changes['products'] ?? {};
    final customers = changes['customers'] ?? {};
    final transactions = changes['transactions'] ?? {};

    return (products['new']?.isNotEmpty == true ||
        products['updated']?.isNotEmpty == true ||
        products['deleted']?.isNotEmpty == true ||
        customers['new']?.isNotEmpty == true ||
        customers['updated']?.isNotEmpty == true ||
        customers['deleted']?.isNotEmpty == true ||
        transactions['new']?.isNotEmpty == true ||
        transactions['deleted']?.isNotEmpty == true);
  }

  /// Get sync status and statistics
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = await getLastSyncTime();
      final totalAttempts = prefs.getInt('totalSyncAttempts') ?? 0;
      final successfulSyncs = prefs.getInt('successfulSyncs') ?? 0;

      // Get pending items count
      final pendingChanges = await _getLocalChanges(null);
      final pendingCount = _countPendingItems(pendingChanges);

      return {
        'isCurrentlySyncing': _isSyncing,
        'lastSyncTime': lastSync?.toIso8601String(),
        'totalSyncAttempts': totalAttempts,
        'successfulSyncs': successfulSyncs,
        'successRate': totalAttempts > 0
            ? (successfulSyncs / totalAttempts * 100).toStringAsFixed(1)
            : '0.0',
        'pendingItemsCount': pendingCount,
        'hasPendingChanges': pendingCount > 0,
      };
    } catch (e) {
      print("SyncService Error getting sync status: $e");
      return {
        'isCurrentlySyncing': _isSyncing,
        'error': e.toString(),
      };
    }
  }

  int _countPendingItems(Map<String, dynamic> changes) {
    int count = 0;
    final products = changes['products'] ?? {};
    final customers = changes['customers'] ?? {};
    final transactions = changes['transactions'] ?? {};

    count += (products['new']?.length ?? 0) as int;
    count += (products['updated']?.length ?? 0) as int;
    count += (products['deleted']?.length ?? 0) as int;
    count += (customers['new']?.length ?? 0) as int;
    count += (customers['updated']?.length ?? 0) as int;
    count += (customers['deleted']?.length ?? 0) as int;
    count += (transactions['new']?.length ?? 0) as int;
    count += (transactions['deleted']?.length ?? 0) as int;

    return count;
  }

  // ...existing code...
} // --- Akhir SyncService ---
