// lib/widgets/sync_status_widget.dart
import 'package:flutter/material.dart';
import '../services/auto_sync_service.dart';
import '../utils/ui_utils.dart';

class SyncStatusWidget extends StatefulWidget {
  final bool showLabel;
  final bool compact;
  final VoidCallback? onTap;

  const SyncStatusWidget({
    super.key,
    this.showLabel = true,
    this.compact = false,
    this.onTap,
  });

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  SyncStatus _currentStatus = SyncStatus.idle;
  bool _hasNetwork = true;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _setupStatusListener();
    _setupNetworkListener();
  }

  void _setupStatusListener() {
    AutoSyncService().syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });

        switch (status) {
          case SyncStatus.syncing:
            _rotationController.repeat();
            break;
          case SyncStatus.success:
            _rotationController.stop();
            _pulseController.forward().then((_) {
              _pulseController.reverse();
            });
            break;
          case SyncStatus.failed:
          case SyncStatus.noInternet:
          case SyncStatus.conflict:
            _rotationController.stop();
            break;
          case SyncStatus.idle:
            _rotationController.stop();
            break;
        }
      }
    });
  }

  void _setupNetworkListener() {
    AutoSyncService().networkStatusStream.listen((hasNetwork) {
      if (mounted) {
        setState(() {
          _hasNetwork = hasNetwork;
        });
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  IconData _getStatusIcon() {
    if (!_hasNetwork) return Icons.wifi_off;

    switch (_currentStatus) {
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.success:
        return Icons.cloud_done;
      case SyncStatus.failed:
        return Icons.sync_problem;
      case SyncStatus.noInternet:
        return Icons.wifi_off;
      case SyncStatus.conflict:
        return Icons.warning;
      case SyncStatus.idle:
        return Icons.cloud;
    }
  }

  Color _getStatusColor() {
    if (!_hasNetwork) return Colors.orange;

    switch (_currentStatus) {
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.failed:
        return Colors.red;
      case SyncStatus.noInternet:
        return Colors.orange;
      case SyncStatus.conflict:
        return Colors.amber;
      case SyncStatus.idle:
        return Colors.grey.shade600;
    }
  }

  String _getStatusText() {
    if (!_hasNetwork) return 'Tidak ada koneksi';

    switch (_currentStatus) {
      case SyncStatus.syncing:
        return 'Menyinkronisasi...';
      case SyncStatus.success:
        return 'Tersinkronisasi';
      case SyncStatus.failed:
        return 'Gagal sinkronisasi';
      case SyncStatus.noInternet:
        return 'Tidak ada koneksi';
      case SyncStatus.conflict:
        return 'Konflik data';
      case SyncStatus.idle:
        return 'Siap';
    }
  }

  Widget _buildIcon() {
    Widget icon = Icon(
      _getStatusIcon(),
      color: _getStatusColor(),
      size: widget.compact ? 16 : 20,
    );

    if (_currentStatus == SyncStatus.syncing) {
      return AnimatedBuilder(
        animation: _rotationController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationController.value * 2 * 3.14159,
            child: icon,
          );
        },
      );
    }

    if (_currentStatus == SyncStatus.success) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_pulseController.value * 0.2),
            child: icon,
          );
        },
      );
    }

    return icon;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(4),
          child: _buildIcon(),
        ),
      );
    }

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _getStatusColor().withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getStatusColor().withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(),
            if (widget.showLabel) ...[
              const SizedBox(width: 8),
              Text(
                _getStatusText(),
                style: TextStyle(
                  color: _getStatusColor(),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SyncStatusIndicator extends StatelessWidget {
  final bool showInAppBar;

  const SyncStatusIndicator({
    super.key,
    this.showInAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    if (showInAppBar) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: SyncStatusWidget(
          compact: true,
          showLabel: false,
          onTap: () => _showSyncDialog(context),
        ),
      );
    }

    return SyncStatusWidget(
      onTap: () => _showSyncDialog(context),
    );
  }

  void _showSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SyncStatusDialog(),
    );
  }
}

class SyncStatusDialog extends StatefulWidget {
  const SyncStatusDialog({super.key});

  @override
  State<SyncStatusDialog> createState() => _SyncStatusDialogState();
}

class _SyncStatusDialogState extends State<SyncStatusDialog> {
  SyncStatistics? _statistics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await AutoSyncService().getSyncStatistics();
      if (mounted) {
        setState(() {
          _statistics = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _performManualSync() async {
    UIUtils.showLoadingDialog(context, message: 'Menyinkronisasi data...');

    try {
      final success = await AutoSyncService().triggerManualSync();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Sinkronisasi berhasil!'
                  : 'Sinkronisasi gagal. Coba lagi nanti.',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );

        if (success) {
          await _loadStatistics(); // Refresh statistics
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.sync, color: Colors.blue),
          SizedBox(width: 8),
          Text('Status Sinkronisasi'),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SyncStatusWidget(showLabel: true),
                  const SizedBox(height: 16),
                  if (_statistics != null) ...[
                    _buildStatItem(
                      'Sinkronisasi Terakhir',
                      _statistics!.lastSuccessfulSync != null
                          ? _formatDateTime(_statistics!.lastSuccessfulSync!)
                          : 'Belum pernah',
                    ),
                    _buildStatItem(
                      'Auto Sync',
                      _statistics!.autoSyncEnabled ? 'Aktif' : 'Nonaktif',
                    ),
                    _buildStatItem(
                      'Interval',
                      '${_statistics!.syncIntervalMinutes} menit',
                    ),
                    _buildStatItem(
                      'Total Sync',
                      '${_statistics!.totalSyncAttempts}',
                    ),
                    _buildStatItem(
                      'Tingkat Keberhasilan',
                      '${(_statistics!.successRate * 100).toStringAsFixed(1)}%',
                    ),
                  ],
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
        ElevatedButton.icon(
          onPressed: _performManualSync,
          icon: const Icon(Icons.refresh),
          label: const Text('Sinkronisasi Sekarang'),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: Colors.grey.shade600)),
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
