// lib/fitur/manage/qris/screens/qris_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/qris_provider.dart'; // Impor provider

class QrisSetupScreen extends StatelessWidget {
  final int userId;
  const QrisSetupScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final provider = QrisProvider(userId: userId);
        provider.loadSavedQrisTemplate();
        return provider;
      },
      child: const _QrisSetupScreenContent(),
    );
  }
}

class _QrisSetupScreenContent extends StatefulWidget {
  const _QrisSetupScreenContent();

  @override
  State<_QrisSetupScreenContent> createState() =>
      _QrisSetupScreenContentState();
}

class _QrisSetupScreenContentState extends State<_QrisSetupScreenContent> {
  // Fungsi pick image sekarang hanya memanggil provider
  Future<void> _pickImageAndScan(
      ImageSource source, QrisProvider provider) async {
    // Provider akan handle state isScanningOrPickingImage
    await provider.pickAndScanImageForSetup(source);
    // Snackbar akan di-handle oleh listener di build method atau setelah await jika diperlukan
  }

  void _showSnackbar(String message,
      {bool isError = false, BuildContext? Ctx}) {
    final currentContext = Ctx ?? context;
    if (!currentContext.mounted) return;

    ScaffoldMessenger.of(currentContext).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrisProvider = context.watch<QrisProvider>();

    // Listener untuk pesan dari provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (qrisProvider.errorMessage != null && mounted) {
        _showSnackbar(qrisProvider.errorMessage!, isError: true);
        // Provider bisa punya method clearMessages() yang dipanggil setelah ini
      }
      if (qrisProvider.successMessage != null && mounted) {
        _showSnackbar(qrisProvider.successMessage!, isError: false);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Pengaturan QRIS',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade800,
        elevation: 0.5,
        centerTitle: true,
        shadowColor: Colors.black.withOpacity(0.06),
      ),
      backgroundColor: const Color(0xFFF7F8FC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Simpan QRIS Anda',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Ambil gambar QRIS statis dari merchant Anda (Gopay Merchant, DANA Bisnis, OVO, dll).',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 35),
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width *
                    0.85, // Sedikit lebih lebar
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.grey.shade200, width: 1),
                      ),
                      child: qrisProvider.selectedImageFileForSetup != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                  qrisProvider.selectedImageFileForSetup!,
                                  fit: BoxFit.contain))
                          : Center(
                              child: Icon(Icons.qr_code_rounded,
                                  size: 90, color: Colors.grey.shade400)),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.photo_library_outlined,
                                  size: 20),
                              label: Text("Galeri",
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              onPressed: qrisProvider.isScanningOrPickingImage
                                  ? null
                                  : () => _pickImageAndScan(
                                      ImageSource.gallery, qrisProvider),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade50,
                                foregroundColor: Colors.blue.shade700,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(
                                    color: Colors.blue.shade200, width: 1),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.camera_alt_outlined,
                                  size: 20),
                              label: Text("Kamera",
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              onPressed: qrisProvider.isScanningOrPickingImage
                                  ? null
                                  : () => _pickImageAndScan(
                                      ImageSource.camera, qrisProvider),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade50,
                                foregroundColor: Colors.blue.shade700,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(
                                    color: Colors.blue.shade200, width: 1),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (qrisProvider.isScanningOrPickingImage &&
                        qrisProvider.selectedImageFileForSetup != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.blue.shade600),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Memindai...",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (qrisProvider.scannedQrDataFromImage != null)
                      Container(
                        margin: const EdgeInsets.only(top: 15),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.green.shade200, width: 1),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Hasil Scan:",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.green.shade300, width: 1),
                              ),
                              child: Text(
                                qrisProvider.scannedQrDataFromImage!,
                                style: GoogleFonts.robotoMono(
                                  fontSize: 11,
                                  color: Colors.green.shade800,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.save_alt_rounded,
                                    size: 20),
                                label: Text(
                                  "Simpan Template Ini",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                onPressed: qrisProvider.isLoading ||
                                        qrisProvider.isScanningOrPickingImage
                                    ? null
                                    : () async {
                                        await qrisProvider
                                            .saveScannedQrisDataAsTemplate();
                                        // Snackbar sudah dihandle oleh listener di atas
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (qrisProvider.selectedImageFileForSetup != null &&
                        !qrisProvider.isScanningOrPickingImage &&
                        qrisProvider.errorMessage != null &&
                        qrisProvider.errorMessage!
                            .contains("QR Code tidak ditemukan"))
                      Container(
                        margin: const EdgeInsets.only(top: 15),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.orange.shade200, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                qrisProvider.errorMessage!,
                                style: GoogleFonts.poppins(
                                  color: Colors.orange.shade800,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}
