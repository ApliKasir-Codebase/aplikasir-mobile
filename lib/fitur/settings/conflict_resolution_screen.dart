// lib/fitur/settings/conflict_resolution_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/sync_service.dart';
import '../../utils/ui_utils.dart';

class ConflictResolutionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> conflicts;

  const ConflictResolutionScreen({
    super.key,
    required this.conflicts,
  });

  @override
  State<ConflictResolutionScreen> createState() =>
      _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState extends State<ConflictResolutionScreen> {
  late List<Map<String, dynamic>> _conflicts;
  final Map<String, String> _resolutions = {};
  final Map<String, Map<String, dynamic>> _resolvedData = {};
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _conflicts = List.from(widget.conflicts);

    // Initialize default resolutions
    for (var conflict in _conflicts) {
      final conflictKey = '${conflict['type']}_${conflict['id']}';

      // Set default resolution based on conflict type and auto-resolution
      if (conflict['resolution'] != null &&
          conflict['resolution'].startsWith('auto')) {
        _resolutions[conflictKey] = 'auto_resolved';
        _resolvedData[conflictKey] = conflict['resolvedData'];
      } else {
        _resolutions[conflictKey] = 'use_server'; // Default to server version
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: UIUtils.buildAppBar(
        title: 'Resolusi Konflik Data',
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: _conflicts.isEmpty
          ? _buildNoConflictsMessage()
          : Column(
              children: [
                _buildConflictSummary(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _conflicts.length,
                    itemBuilder: (context, index) {
                      return _buildConflictCard(_conflicts[index], index);
                    },
                  ),
                ),
                _buildResolveButton(),
              ],
            ),
    );
  }

  Widget _buildNoConflictsMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak Ada Konflik',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Semua data telah tersinkronisasi dengan baik',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConflictSummary() {
    final productConflicts =
        _conflicts.where((c) => c['type'] == 'product').length;
    final customerConflicts =
        _conflicts.where((c) => c['type'] == 'customer').length;
    final transactionConflicts =
        _conflicts.where((c) => c['type'] == 'transaction').length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange.shade600, size: 24),
              const SizedBox(width: 8),
              Text(
                'Konflik Data Ditemukan',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Terdapat perbedaan data antara lokal dan server yang memerlukan resolusi manual:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 8),
          if (productConflicts > 0)
            _buildConflictSummaryItem(
                'Produk', productConflicts, Icons.inventory),
          if (customerConflicts > 0)
            _buildConflictSummaryItem(
                'Pelanggan', customerConflicts, Icons.people),
          if (transactionConflicts > 0)
            _buildConflictSummaryItem(
                'Transaksi', transactionConflicts, Icons.receipt),
        ],
      ),
    );
  }

  Widget _buildConflictSummaryItem(String type, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.orange.shade600),
          const SizedBox(width: 8),
          Text(
            '$type: $count konflik',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictCard(Map<String, dynamic> conflict, int index) {
    final conflictKey = '${conflict['type']}_${conflict['id']}';
    final currentResolution = _resolutions[conflictKey] ?? 'use_server';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConflictHeader(conflict, index),
            const SizedBox(height: 12),
            _buildConflictDetails(conflict),
            const SizedBox(height: 16),
            _buildResolutionOptions(conflict, conflictKey, currentResolution),
            if (currentResolution == 'merge')
              _buildMergeFields(conflict, conflictKey),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictHeader(Map<String, dynamic> conflict, int index) {
    IconData icon;
    Color iconColor;
    String typeText;

    switch (conflict['type']) {
      case 'product':
        icon = Icons.inventory;
        iconColor = Colors.blue.shade600;
        typeText = 'Produk';
        break;
      case 'customer':
        icon = Icons.person;
        iconColor = Colors.green.shade600;
        typeText = 'Pelanggan';
        break;
      case 'transaction':
        icon = Icons.receipt;
        iconColor = Colors.purple.shade600;
        typeText = 'Transaksi';
        break;
      default:
        icon = Icons.error;
        iconColor = Colors.red.shade600;
        typeText = 'Unknown';
    }

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$typeText #${index + 1}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              Text(
                conflict['message'] ?? 'Konflik data terdeteksi',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        if (conflict['resolution']?.startsWith('auto') == true)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Auto Resolved',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.green.shade700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildConflictDetails(Map<String, dynamic> conflict) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (conflict['conflicts'] != null)
            ..._buildFieldConflicts(conflict['conflicts']),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDataColumn(
                  'Data Server',
                  conflict['serverData'],
                  Colors.blue.shade600,
                  conflict['serverUpdatedAt'],
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(
                child: _buildDataColumn(
                  'Data Lokal',
                  conflict['localData'],
                  Colors.green.shade600,
                  conflict['localUpdatedAt'],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFieldConflicts(List<dynamic> conflicts) {
    return conflicts.map<Widget>((fieldConflict) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(Icons.compare_arrows, size: 16, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            Text(
              '${fieldConflict['field']}: ',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            Expanded(
              child: Text(
                'Server: "${fieldConflict['serverValue']}" ↔ Lokal: "${fieldConflict['localValue']}"',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildDataColumn(String title, Map<String, dynamic>? data, Color color,
      String? timestamp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        if (data != null) ...[
          Text(
            data['nama_produk'] ??
                data['nama_pelanggan'] ??
                'ID: ${data['id']}',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (timestamp != null)
            Text(
              _formatDateTime(timestamp),
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildResolutionOptions(Map<String, dynamic> conflict,
      String conflictKey, String currentResolution) {
    final isAutoResolved = conflict['resolution']?.startsWith('auto') == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilihan Resolusi:',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        if (isAutoResolved)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_fix_high,
                    color: Colors.green.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Konflik ini telah diselesaikan secara otomatis menggunakan strategi: ${conflict['resolution']}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          _buildResolutionOption(
            conflictKey,
            'use_server',
            'Gunakan Data Server',
            'Data dari server akan digunakan',
            Icons.cloud,
            Colors.blue.shade600,
            currentResolution,
          ),
          _buildResolutionOption(
            conflictKey,
            'use_local',
            'Gunakan Data Lokal',
            'Data lokal akan menimpa data server',
            Icons.phone_android,
            Colors.green.shade600,
            currentResolution,
          ),
          if (conflict['type'] != 'transaction')
            _buildResolutionOption(
              conflictKey,
              'merge',
              'Gabungkan Manual',
              'Pilih field mana yang akan digunakan',
              Icons.merge,
              Colors.orange.shade600,
              currentResolution,
            ),
        ],
      ],
    );
  }

  Widget _buildResolutionOption(
    String conflictKey,
    String value,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String currentResolution,
  ) {
    final isSelected = currentResolution == value;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _resolutions[conflictKey] = value;
              if (value != 'merge') {
                _resolvedData.remove(conflictKey);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? color : Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? color : Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isSelected
                              ? color.withOpacity(0.8)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: color,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMergeFields(Map<String, dynamic> conflict, String conflictKey) {
    final conflicts = conflict['conflicts'] as List<dynamic>? ?? [];
    final serverData = conflict['serverData'] as Map<String, dynamic>? ?? {};
    final localData = conflict['localData'] as Map<String, dynamic>? ?? {};

    // Initialize resolved data with server data as base
    _resolvedData[conflictKey] ??= Map<String, dynamic>.from(serverData);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pilih nilai untuk setiap field:',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 8),
          ...conflicts.map<Widget>((fieldConflict) {
            final fieldName = fieldConflict['field'] as String;
            final serverValue = fieldConflict['serverValue'];
            final localValue = fieldConflict['localValue'];

            return _buildFieldSelector(
              conflictKey,
              fieldName,
              serverValue,
              localValue,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildFieldSelector(
    String conflictKey,
    String fieldName,
    dynamic serverValue,
    dynamic localValue,
  ) {
    final resolvedData = _resolvedData[conflictKey] ?? {};
    final currentValue = resolvedData[fieldName];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fieldName,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _buildValueOption(
                  conflictKey,
                  fieldName,
                  serverValue,
                  'Server',
                  Colors.blue.shade600,
                  currentValue == serverValue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildValueOption(
                  conflictKey,
                  fieldName,
                  localValue,
                  'Lokal',
                  Colors.green.shade600,
                  currentValue == localValue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValueOption(
    String conflictKey,
    String fieldName,
    dynamic value,
    String source,
    Color color,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _resolvedData[conflictKey] ??= {};
          _resolvedData[conflictKey]![fieldName] = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  source,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  Icon(Icons.check, color: color, size: 14),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value.toString(),
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey.shade800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolveButton() {
    final hasUnresolvedConflicts = _resolutions.values.any((resolution) =>
        resolution.isEmpty ||
        resolution == 'merge' && !_hasCompleteMergeData());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: hasUnresolvedConflicts || _isResolving
                ? null
                : _resolveConflicts,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isResolving
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Menerapkan Resolusi...',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Terapkan Resolusi (${_conflicts.length} konflik)',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  bool _hasCompleteMergeData() {
    for (final entry in _resolutions.entries) {
      if (entry.value == 'merge') {
        final conflictKey = entry.key;
        final conflict = _conflicts.firstWhere(
          (c) => '${c['type']}_${c['id']}' == conflictKey,
          orElse: () => {},
        );

        if (conflict.isNotEmpty) {
          final conflicts = conflict['conflicts'] as List<dynamic>? ?? [];
          final resolvedData = _resolvedData[conflictKey] ?? {};

          for (final fieldConflict in conflicts) {
            final fieldName = fieldConflict['field'] as String;
            if (!resolvedData.containsKey(fieldName)) {
              return false;
            }
          }
        }
      }
    }
    return true;
  }

  Future<void> _resolveConflicts() async {
    setState(() {
      _isResolving = true;
    });

    try {
      // Prepare conflicts with resolutions
      final conflictsToResolve = _conflicts.map((conflict) {
        final conflictKey = '${conflict['type']}_${conflict['id']}';
        final resolution = _resolutions[conflictKey] ?? 'use_server';
        final resolvedData = _resolvedData[conflictKey];

        return {
          ...conflict,
          'resolution': resolution,
          if (resolvedData != null) 'resolvedData': resolvedData,
        };
      }).toList();

      // Call sync service to resolve conflicts
      final success = await SyncService().resolveConflicts(conflictsToResolve);

      if (mounted) {
        if (success) {
          UIUtils.showCustomSnackbar(
            context,
            message: 'Semua konflik berhasil diselesaikan!',
            type: SnackBarType.success,
          );
          Navigator.of(context).pop(true); // Return success
        } else {
          UIUtils.showCustomSnackbar(
            context,
            message: 'Gagal menyelesaikan beberapa konflik. Silakan coba lagi.',
            type: SnackBarType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        UIUtils.showCustomSnackbar(
          context,
          message: 'Error: ${e.toString()}',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Bantuan Resolusi Konflik',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Konflik terjadi ketika data yang sama diubah baik di aplikasi lokal maupun di server. Pilihan resolusi:',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 12),
              _buildHelpItem(
                'Gunakan Data Server',
                'Data dari server akan digunakan, perubahan lokal akan ditimpa.',
                Icons.cloud,
                Colors.blue.shade600,
              ),
              _buildHelpItem(
                'Gunakan Data Lokal',
                'Data lokal akan menimpa data di server.',
                Icons.phone_android,
                Colors.green.shade600,
              ),
              _buildHelpItem(
                'Gabungkan Manual',
                'Anda dapat memilih nilai yang diinginkan untuk setiap field yang berkonflik.',
                Icons.merge,
                Colors.orange.shade600,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(
      String title, String description, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
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
    } catch (e) {
      return timestamp;
    }
  }
}
