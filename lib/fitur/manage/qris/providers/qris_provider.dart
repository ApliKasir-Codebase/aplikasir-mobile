// lib/fitur/manage/qris/providers/qris_provider.dart
import 'dart:io';
import 'dart:convert'; // Untuk utf8.encode
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QrisProvider extends ChangeNotifier {
  final int userId; // Mungkin berguna untuk scope di masa depan
  final ImagePicker _imagePicker = ImagePicker();
  final BarcodeScanner _barcodeScanner =
      BarcodeScanner(formats: [BarcodeFormat.qrCode]);

  String? _rawQrisTemplate; // Template mentah yang tersimpan
  String? _scannedQrDataFromImage; // Hasil scan QR dari gambar (untuk setup)
  File? _selectedImageFileForSetup; // File gambar yang DIPILIH untuk setup QRIS

  bool _isLoading = false; // Loading umum untuk load/save/delete template
  bool _isScanningOrPickingImage =
      false; // Loading saat pilih gambar & scan di setup screen
  String? _errorMessage;
  String? _successMessage;

  // Kunci SharedPreferences (konsisten dengan QrisSetupScreen lama)
  static const String qrisDataKey = 'raw_qris_data';

  // Getters
  String? get rawQrisTemplate => _rawQrisTemplate;
  String? get scannedQrDataFromImage => _scannedQrDataFromImage;
  File? get selectedImageFileForSetup => _selectedImageFileForSetup;
  bool get isLoading => _isLoading;
  bool get isScanningOrPickingImage => _isScanningOrPickingImage;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  QrisProvider({required this.userId}) {
    // Removed automatic loadSavedQrisTemplate() from constructor
  }

  @override
  void dispose() {
    _barcodeScanner.close();
    // Hapus file temporary jika ada saat provider di-dispose
    if (_selectedImageFileForSetup != null &&
        _selectedImageFileForSetup!.existsSync()) {
      _selectedImageFileForSetup!.delete().catchError((e) {
        print("Error deleting temp setup image on dispose: $e");
        return _selectedImageFileForSetup!;
      });
    }
    super.dispose();
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    // notifyListeners(); // Biasanya dipanggil oleh method utama
  }

  void _clearScanAndImageSelection() {
    if (_selectedImageFileForSetup != null &&
        _selectedImageFileForSetup!.existsSync()) {
      _selectedImageFileForSetup!.delete().catchError((e) {
        print("Error deleting temp setup image: $e");
        return _selectedImageFileForSetup!;
      });
    }
    _selectedImageFileForSetup = null;
    _scannedQrDataFromImage = null;
    // _clearMessages(); // Jangan clear message global di sini, mungkin ada pesan lain
    // notifyListeners(); // Akan dipanggil oleh method yang memanggil ini
  }

  Future<void> loadSavedQrisTemplate() async {
    _isLoading = true;
    _clearMessages();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _rawQrisTemplate = prefs.getString(qrisDataKey);
      _successMessage = _rawQrisTemplate != null
          ? null
          : null; // Tidak perlu pesan sukses untuk load
    } catch (e) {
      _errorMessage = "Gagal memuat template QRIS tersimpan: ${e.toString()}";
      print("Error loading QRIS template: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pickAndScanImageForSetup(ImageSource source) async {
    if (_isScanningOrPickingImage) return;
    _isScanningOrPickingImage = true;
    _clearMessages();
    _clearScanAndImageSelection(); // Bersihkan state scan sebelumnya
    notifyListeners();

    try {
      final XFile? pickedFile =
          await _imagePicker.pickImage(source: source, imageQuality: 85);
      if (pickedFile != null) {
        _selectedImageFileForSetup = File(pickedFile.path);
        notifyListeners(); // Update UI untuk tampilkan gambar terpilih

        final InputImage inputImage =
            InputImage.fromFilePath(_selectedImageFileForSetup!.path);
        final List<Barcode> barcodes =
            await _barcodeScanner.processImage(inputImage);

        String? foundQrData;
        if (barcodes.isNotEmpty) {
          for (var barcode in barcodes) {
            if (barcode.format == BarcodeFormat.qrCode &&
                barcode.rawValue != null) {
              foundQrData = barcode.rawValue;
              break;
            }
          }
        }

        if (foundQrData != null) {
          _scannedQrDataFromImage = foundQrData;
          _successMessage = "QR Code berhasil dipindai dari gambar!";
        } else {
          _errorMessage = "QR Code tidak ditemukan pada gambar yang dipilih.";
          // Jangan hapus _selectedImageFileForSetup agar user bisa lihat gambar yg gagal di-scan
        }
      } else {
        _errorMessage = "Pemilihan gambar dibatalkan.";
      }
    } catch (e) {
      _errorMessage = "Gagal memproses gambar: ${e.toString()}";
      // Hapus gambar jika terjadi error, agar tidak ada preview gambar yg error
      _clearScanAndImageSelection();
    } finally {
      _isScanningOrPickingImage = false;
      notifyListeners();
    }
  }

  Future<bool> saveScannedQrisDataAsTemplate() async {
    if (_scannedQrDataFromImage == null || _scannedQrDataFromImage!.isEmpty) {
      _clearMessages();
      _errorMessage =
          "Tidak ada data QRIS dari hasil scan untuk disimpan sebagai template.";
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _clearMessages();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(qrisDataKey, _scannedQrDataFromImage!);
      _rawQrisTemplate = _scannedQrDataFromImage;
      _clearScanAndImageSelection(); // Bersihkan UI scan setelah berhasil disimpan
      _successMessage = "Template QRIS berhasil disimpan!";
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "Gagal menyimpan template QRIS: ${e.toString()}";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSavedQrisTemplate() async {
    _isLoading = true;
    _clearMessages();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(qrisDataKey);
      _rawQrisTemplate = null;
      _clearScanAndImageSelection(); // Bersihkan UI scan juga
      _successMessage = "Template QRIS berhasil dihapus.";
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "Gagal menghapus template QRIS: ${e.toString()}";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Untuk QrisDisplayScreen: menghasilkan string QRIS dinamis
  String? generateDynamicQrisForDisplay(double totalAmount) {
    if (_rawQrisTemplate == null || _rawQrisTemplate!.isEmpty) {
      print(
          "QRIS Provider: Template QRIS belum diatur untuk generate QR dinamis.");
      return null;
    }

    try {
      // Remove existing CRC (last 4 chars)
      String templateNoCRC =
          _rawQrisTemplate!.substring(0, _rawQrisTemplate!.length - 4);

      // Ensure dynamic initiation method '010212'
      if (!templateNoCRC.contains("010212") &&
          templateNoCRC.contains("010211")) {
        templateNoCRC = templateNoCRC.replaceFirst('010211', '010212');
      }

      // Build amount TLV: tag 54
      final String amountValue = totalAmount.toStringAsFixed(2);
      final String amountLen = amountValue.length.toString().padLeft(2, '0');
      final String tlvAmount = '54' + amountLen + amountValue;

      // Insert TLV before tag 58 or 59 or 62
      int insertPos;
      int pos58 = templateNoCRC.indexOf('58');
      int pos59 = templateNoCRC.indexOf('59');
      if (pos58 != -1 && (pos59 == -1 || pos58 < pos59)) {
        insertPos = pos58;
      } else if (pos59 != -1) {
        insertPos = pos59;
      } else {
        insertPos = templateNoCRC.indexOf('62');
        if (insertPos == -1) insertPos = templateNoCRC.length;
      }

      final String payloadNoCRC = templateNoCRC.substring(0, insertPos) +
          tlvAmount +
          templateNoCRC.substring(insertPos);

      // Append CRC field tag and length (6304) for calculation
      final String toCrc = payloadNoCRC + '6304';

      // Compute CRC16-CCITT (polynomial 0x1021, initial 0xFFFF)
      int crc = 0xFFFF;
      for (var byte in utf8.encode(toCrc)) {
        crc ^= (byte << 8);
        for (int i = 0; i < 8; i++) {
          if ((crc & 0x8000) != 0)
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
          else
            crc = (crc << 1) & 0xFFFF;
        }
      }
      final String crcHex = crc.toRadixString(16).toUpperCase().padLeft(4, '0');

      // Final payload with CRC tag
      return payloadNoCRC + '63' + '04' + crcHex;
    } catch (e) {
      print('Error generateDynamicQrisForDisplay: $e');
      return null;
    }
  }

  // Public method to clear UI scan state from screens
  void clearUiScanState() {
    _clearScanAndImageSelection();
    notifyListeners();
  }
}
