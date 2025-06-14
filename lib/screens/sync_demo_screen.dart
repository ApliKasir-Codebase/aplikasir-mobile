import 'package:flutter/material.dart';
import '../widgets/sync_control_widget.dart';
import '../services/sync_service.dart';

class SyncDemoScreen extends StatefulWidget {
  const SyncDemoScreen({Key? key}) : super(key: key);

  @override
  State<SyncDemoScreen> createState() => _SyncDemoScreenState();
}

class _SyncDemoScreenState extends State<SyncDemoScreen> {
  final SyncService _syncService = SyncService();
  Map<String, dynamic>? _syncStatus;

  @override
  void initState() {
    super.initState();
    _loadSyncStatus();
  }

  Future<void> _loadSyncStatus() async {
    try {
      final status = await _syncService.getSyncStatus();
      setState(() {
        _syncStatus = status;
      });
    } catch (e) {
      print('Error loading sync status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo Sinkronisasi'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kontrol Sinkronisasi Data',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Atur cara data disinkronisasi antara aplikasi dan server. '
                      'Anda dapat memilih untuk mengirim data ke server, mengambil data dari server, '
                      'atau keduanya sekaligus.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Basic sync controls
            const SyncControlWidget(
              showDetailedInfo: false,
            ),

            const SizedBox(height: 16),

            // Advanced sync controls
            const SyncControlWidget(
              showDetailedInfo: true,
            ),

            const SizedBox(height: 16),

            // Quick actions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aksi Cepat',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),

                    // Quick action buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _performQuickSync('upload'),
                          icon: const Icon(Icons.cloud_upload, size: 18),
                          label: const Text('Upload Saja'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _performQuickSync('download'),
                          icon: const Icon(Icons.cloud_download, size: 18),
                          label: const Text('Download Saja'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _performQuickSync('full'),
                          icon: const Icon(Icons.sync_alt, size: 18),
                          label: const Text('Sinkronisasi Penuh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Sync status info
            if (_syncStatus != null) _buildSyncStatusInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status Sistem Sinkronisasi',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildStatusRow(
                'Sedang Sinkronisasi',
                _syncStatus!['isCurrentlySyncing'] == true ? 'Ya' : 'Tidak',
                _syncStatus!['isCurrentlySyncing'] == true
                    ? Colors.orange
                    : Colors.green),
            if (_syncStatus!['lastSyncTime'] != null)
              _buildStatusRow('Sinkronisasi Terakhir',
                  _formatDateTime(_syncStatus!['lastSyncTime']), Colors.blue),
            _buildStatusRow('Total Percobaan',
                _syncStatus!['totalSyncAttempts'].toString(), Colors.grey),
            _buildStatusRow('Berhasil',
                _syncStatus!['successfulSyncs'].toString(), Colors.green),
            _buildStatusRow('Tingkat Keberhasilan',
                '${_syncStatus!['successRate']}%', Colors.purple),
            _buildStatusRow(
                'Data Menunggu',
                _syncStatus!['pendingItemsCount'].toString(),
                _syncStatus!['pendingItemsCount'] > 0
                    ? Colors.orange
                    : Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performQuickSync(String type) async {
    try {
      bool success = false;
      String message = '';

      switch (type) {
        case 'upload':
          success = await _syncService.performUploadOnlySync();
          message = success
              ? 'Data berhasil dikirim ke server!'
              : 'Gagal mengirim data ke server';
          break;
        case 'download':
          success = await _syncService.performDownloadOnlySync();
          message = success
              ? 'Data berhasil diambil dari server!'
              : 'Gagal mengambil data dari server';
          break;
        case 'full':
          success = await _syncService.performFullSync();
          message = success
              ? 'Sinkronisasi penuh berhasil!'
              : 'Sinkronisasi penuh gagal';
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );

        // Refresh status
        _loadSyncStatus();
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
    }
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Belum pernah';

    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Format tidak valid';
    }
  }
}
