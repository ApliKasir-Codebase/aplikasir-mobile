// lib/fitur/settings/sync_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auto_sync_service.dart';
import '../../utils/ui_utils.dart';
import '../../widgets/sync_status_widget.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  bool _autoSyncEnabled = true;
  bool _syncOnDataChange = true;
  bool _syncOnNetworkChange = true;
  int _syncInterval = 30;
  bool _isLoading = true;
  SyncStatistics? _statistics;

  final List<int> _intervalOptions = [5, 15, 30, 60, 120]; // minutes

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    try {
      final autoSyncService = AutoSyncService();
      final stats = await autoSyncService.getSyncStatistics();

      if (mounted) {
        setState(() {
          _autoSyncEnabled = autoSyncService.isAutoSyncEnabled;
          _syncOnDataChange = autoSyncService.syncOnDataChange;
          _syncOnNetworkChange = autoSyncService.syncOnNetworkChange;
          _syncInterval = autoSyncService.syncIntervalMinutes;
          _statistics = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat pengaturan sync: $e')),
        );
      }
    }
  }

  Future<void> _updateSettings({
    bool? autoSyncEnabled,
    bool? syncOnDataChange,
    bool? syncOnNetworkChange,
    int? syncIntervalMinutes,
  }) async {
    try {
      final autoSyncService = AutoSyncService();
      await autoSyncService.updateSettings(
        autoSyncEnabled: autoSyncEnabled,
        syncOnDataChange: syncOnDataChange,
        syncOnNetworkChange: syncOnNetworkChange,
        syncIntervalMinutes: syncIntervalMinutes,
      );

      if (mounted) {
        setState(() {
          if (autoSyncEnabled != null) _autoSyncEnabled = autoSyncEnabled;
          if (syncOnDataChange != null) _syncOnDataChange = syncOnDataChange;
          if (syncOnNetworkChange != null)
            _syncOnNetworkChange = syncOnNetworkChange;
          if (syncIntervalMinutes != null) _syncInterval = syncIntervalMinutes;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pengaturan berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah pengaturan: $e')),
      );
    }
  }

  Future<void> _performManualSync() async {
    try {
      UIUtils.showLoadingDialog(context, message: 'Menyinkronkan data...');

      final autoSyncService = AutoSyncService();
      final success = await autoSyncService.triggerManualSync();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sinkronisasi berhasil! Data telah diperbarui.'),
              backgroundColor: Colors.green,
            ),
          );

          // Refresh statistics
          _loadCurrentSettings();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sinkronisasi gagal. Coba lagi nanti.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal melakukan sinkronisasi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Pengaturan Sinkronisasi',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sync Status Card
                  _buildSyncStatusCard(),
                  const SizedBox(height: 16),

                  // Auto Sync Settings
                  _buildAutoSyncSettings(),
                  const SizedBox(height: 16),

                  // Manual Sync
                  _buildManualSyncSection(),
                  const SizedBox(height: 16),

                  // Sync Statistics
                  if (_statistics != null) _buildSyncStatistics(),
                ],
              ),
            ),
    );
  }

  Widget _buildSyncStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sync,
                  color: Colors.blue.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Status Sinkronisasi',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SyncStatusWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoSyncSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sinkronisasi Otomatis',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Auto Sync Toggle
            SwitchListTile(
              title: Text(
                'Aktifkan Auto Sync',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Sinkronisasi data secara otomatis',
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
              value: _autoSyncEnabled,
              onChanged: (enabled) => _updateSettings(autoSyncEnabled: enabled),
              activeColor: Colors.blue.shade600,
              contentPadding: EdgeInsets.zero,
            ),

            const Divider(),

            // Sync on Data Change
            SwitchListTile(
              title: Text(
                'Sync saat Data Berubah',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Sinkronisasi otomatis saat ada perubahan data',
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
              value: _syncOnDataChange,
              onChanged: _autoSyncEnabled
                  ? (enabled) => _updateSettings(syncOnDataChange: enabled)
                  : null,
              activeColor: Colors.blue.shade600,
              contentPadding: EdgeInsets.zero,
            ),

            const Divider(),

            // Sync on Network Change
            SwitchListTile(
              title: Text(
                'Sync saat Jaringan Tersambung',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Sinkronisasi otomatis saat jaringan kembali tersambung',
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
              value: _syncOnNetworkChange,
              onChanged: _autoSyncEnabled
                  ? (enabled) => _updateSettings(syncOnNetworkChange: enabled)
                  : null,
              activeColor: Colors.blue.shade600,
              contentPadding: EdgeInsets.zero,
            ),

            const Divider(),

            // Sync Interval
            ListTile(
              title: Text(
                'Interval Sinkronisasi',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Frekuensi sinkronisasi otomatis',
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
              trailing: DropdownButton<int>(
                value: _syncInterval,
                onChanged: _autoSyncEnabled
                    ? (value) {
                        if (value != null) {
                          _updateSettings(syncIntervalMinutes: value);
                        }
                      }
                    : null,
                items: _intervalOptions.map((interval) {
                  return DropdownMenuItem<int>(
                    value: interval,
                    child: Text(
                      '${interval} menit',
                      style: GoogleFonts.poppins(),
                    ),
                  );
                }).toList(),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualSyncSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sinkronisasi Manual',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lakukan sinkronisasi data secara manual untuk memastikan data terkini.',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _performManualSync,
                icon: const Icon(Icons.sync),
                label: Text(
                  'Sinkronkan Sekarang',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatistics() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistik Sinkronisasi',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatisticRow(
              'Terakhir Sync',
              _statistics!.lastSuccessfulSync != null
                  ? _formatDateTime(_statistics!.lastSuccessfulSync!)
                  : 'Belum pernah',
            ),
            _buildStatisticRow(
              'Total Percobaan',
              _statistics!.totalSyncAttempts.toString(),
            ),
            _buildStatisticRow(
              'Berhasil',
              _statistics!.successfulSyncs.toString(),
            ),
            _buildStatisticRow(
              'Tingkat Keberhasilan',
              '${(_statistics!.successRate * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} menit lalu';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} jam lalu';
    } else {
      return '${difference.inDays} hari lalu';
    }
  }
}
