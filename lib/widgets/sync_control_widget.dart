import 'package:flutter/material.dart';
import '../services/sync_service.dart';

class SyncControlWidget extends StatefulWidget {
  final bool showDetailedInfo;
  final VoidCallback? onSyncComplete;

  const SyncControlWidget({
    Key? key,
    this.showDetailedInfo = false,
    this.onSyncComplete,
  }) : super(key: key);

  @override
  State<SyncControlWidget> createState() => _SyncControlWidgetState();
}

class _SyncControlWidgetState extends State<SyncControlWidget> {
  final SyncService _syncService = SyncService();
  Map<String, dynamic>? _syncStatus;
  bool _isLoading = true;

  // New variables for sync direction and data type selection
  bool _uploadEnabled = true;
  bool _downloadEnabled = true;
  final Set<String> _selectedDataTypes = {
    'products',
    'customers',
    'transactions'
  };

  @override
  void initState() {
    super.initState();
    _loadSyncStatus();
  }

  Future<void> _loadSyncStatus() async {
    setState(() => _isLoading = true);
    try {
      final status = await _syncService.getSyncStatus();
      setState(() {
        _syncStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading sync status: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performSync(
      {bool uploadOnly = false,
      bool fullSync = false,
      bool directional = false}) async {
    try {
      bool success;
      if (uploadOnly) {
        success = await _syncService.performUploadOnlySync();
      } else if (fullSync) {
        success = await _syncService.performFullSync();
      } else if (directional) {
        // Perform directional sync based on enabled options
        success = await _syncService.performDirectionalSync(
          uploadEnabled: _uploadEnabled,
          downloadEnabled: _downloadEnabled,
          dataTypes: _selectedDataTypes.toList(),
        );
      } else {
        success = await _syncService.performSync();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Sinkronisasi berhasil!'
                : 'Sinkronisasi gagal, coba lagi'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );

        if (success && widget.onSyncComplete != null) {
          widget.onSyncComplete!();
        }

        await _loadSyncStatus(); // Refresh status
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Memuat status sinkronisasi...'),
            ],
          ),
        ),
      );
    }

    if (_syncStatus == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Gagal memuat status sinkronisasi'),
        ),
      );
    }

    final isCurrentlySyncing = _syncStatus!['isCurrentlySyncing'] ?? false;
    final lastSyncTime = _syncStatus!['lastSyncTime'];
    final pendingCount = _syncStatus!['pendingItemsCount'] ?? 0;
    final successRate = _syncStatus!['successRate'] ?? '0.0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with sync status
            Row(
              children: [
                Icon(
                  isCurrentlySyncing
                      ? Icons.sync
                      : (pendingCount > 0 ? Icons.sync_problem : Icons.sync),
                  color: isCurrentlySyncing
                      ? Colors.blue
                      : (pendingCount > 0 ? Colors.orange : Colors.green),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCurrentlySyncing
                        ? 'Sedang sinkronisasi...'
                        : (pendingCount > 0
                            ? '$pendingCount perubahan menunggu sinkronisasi'
                            : 'Data tersinkronisasi'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadSyncStatus,
                  tooltip: 'Refresh status',
                ),
              ],
            ),

            if (widget.showDetailedInfo) ...[
              const Divider(),

              // Last sync time
              if (lastSyncTime != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Terakhir sinkronisasi: ${_formatDateTime(lastSyncTime)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),

              // Success rate
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Tingkat keberhasilan: $successRate%',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ],

            // Action buttons
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: isCurrentlySyncing ? null : () => _performSync(),
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Sinkronisasi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (pendingCount > 0)
                  OutlinedButton.icon(
                    onPressed: isCurrentlySyncing
                        ? null
                        : () => _performSync(uploadOnly: true),
                    icon: const Icon(Icons.upload, size: 18),
                    label: const Text('Kirim Saja'),
                  ),
                if (widget.showDetailedInfo)
                  OutlinedButton.icon(
                    onPressed: isCurrentlySyncing
                        ? null
                        : () => _performSync(fullSync: true),
                    icon: const Icon(Icons.cloud_download, size: 18),
                    label: const Text('Download Ulang'),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // New section for sync direction controls
            if (widget.showDetailedInfo) ...[
              const SizedBox(height: 16),
              _buildSyncDirectionControls(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyncDirectionControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kontrol Arah Sinkronisasi',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            // Direction switches
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    title: const Text('Upload ke Server'),
                    subtitle: const Text('Kirim data lokal ke server'),
                    value: _uploadEnabled,
                    onChanged: (value) {
                      setState(() {
                        _uploadEnabled = value;
                        // At least one direction must be enabled
                        if (!_uploadEnabled && !_downloadEnabled) {
                          _downloadEnabled = true;
                        }
                      });
                    },
                    dense: true,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    title: const Text('Download dari Server'),
                    subtitle: const Text('Ambil data dari server'),
                    value: _downloadEnabled,
                    onChanged: (value) {
                      setState(() {
                        _downloadEnabled = value;
                        // At least one direction must be enabled
                        if (!_uploadEnabled && !_downloadEnabled) {
                          _uploadEnabled = true;
                        }
                      });
                    },
                    dense: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Data type selection
            Text(
              'Pilih Jenis Data:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Produk'),
                  selected: _selectedDataTypes.contains('products'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDataTypes.add('products');
                      } else {
                        _selectedDataTypes.remove('products');
                        // At least one data type must be selected
                        if (_selectedDataTypes.isEmpty) {
                          _selectedDataTypes.add('products');
                        }
                      }
                    });
                  },
                ),
                FilterChip(
                  label: const Text('Pelanggan'),
                  selected: _selectedDataTypes.contains('customers'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDataTypes.add('customers');
                      } else {
                        _selectedDataTypes.remove('customers');
                        if (_selectedDataTypes.isEmpty) {
                          _selectedDataTypes.add('customers');
                        }
                      }
                    });
                  },
                ),
                FilterChip(
                  label: const Text('Transaksi'),
                  selected: _selectedDataTypes.contains('transactions'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDataTypes.add('transactions');
                      } else {
                        _selectedDataTypes.remove('transactions');
                        if (_selectedDataTypes.isEmpty) {
                          _selectedDataTypes.add('transactions');
                        }
                      }
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Custom sync button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _performSync(directional: true),
                icon: const Icon(Icons.sync_alt),
                label: Text(_getSyncButtonText()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSyncButtonText() {
    if (_uploadEnabled && _downloadEnabled) {
      return 'Sinkronisasi Dua Arah';
    } else if (_uploadEnabled) {
      return 'Upload ke Server';
    } else if (_downloadEnabled) {
      return 'Download dari Server';
    } else {
      return 'Sinkronisasi';
    }
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Baru saja';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} menit lalu';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} jam lalu';
      } else {
        return '${difference.inDays} hari lalu';
      }
    } catch (e) {
      return 'Tidak diketahui';
    }
  }
}

// Simple sync button for quick access
class QuickSyncButton extends StatefulWidget {
  final VoidCallback? onSyncComplete;

  const QuickSyncButton({
    Key? key,
    this.onSyncComplete,
  }) : super(key: key);

  @override
  State<QuickSyncButton> createState() => _QuickSyncButtonState();
}

class _QuickSyncButtonState extends State<QuickSyncButton> {
  final SyncService _syncService = SyncService();
  bool _isSyncing = false;

  Future<void> _performQuickSync() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final success = await _syncService.performSync();

      if (mounted) {
        if (success && widget.onSyncComplete != null) {
          widget.onSyncComplete!();
        }

        // Show brief feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Tersinkronisasi!' : 'Gagal sinkronisasi'),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _isSyncing ? null : _performQuickSync,
      icon: _isSyncing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync),
      tooltip: 'Sinkronisasi data',
    );
  }
}
