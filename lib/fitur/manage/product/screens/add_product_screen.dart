// lib/fitur/manage/product/add_product_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:aplikasir_mobile/model/product_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_image/crop_image.dart';
// Hapus path_provider dan path jika tidak digunakan langsung di sini
// import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart'; // Impor Provider

// --- Impor Provider Produk ---
import 'package:aplikasir_mobile/fitur/manage/product/providers/product_provider.dart';
import 'package:aplikasir_mobile/theme/app_theme.dart';
import 'package:aplikasir_mobile/utils/ui_utils.dart';
import 'package:aplikasir_mobile/widgets/common_widgets.dart';
// Model dan DB Helper tidak diimpor langsung jika semua via provider
// import 'package:aplikasir_mobile/model/product_model.dart';
// import 'package:aplikasir_mobile/helper/db_helper.dart';

class AddProductScreen extends StatefulWidget {
  final int
      userId; // Tetap dibutuhkan untuk inisialisasi jika provider tidak di-create di atasnya
  final String? initialName;
  final String? initialCode;
  final File? initialImageFile; // Ini adalah temporary file dari scan

  const AddProductScreen({
    super.key,
    required this.userId, // Atau ambil dari ProductProvider jika sudah ada di tree
    this.initialName,
    this.initialCode,
    this.initialImageFile,
  });

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  late CropController _cropController;

  late TextEditingController _nameController;
  late TextEditingController _codeController;
  final TextEditingController _stockController =
      TextEditingController(text: '0');
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _sellingPriceController = TextEditingController();

  File? _newCroppedImageFile; // File temporary hasil crop
  // Hapus _prefilledImageFile, gunakan _newCroppedImageFile dari widget.initialImageFile
  // Removed unused field _imageRemoved

  bool _isCropping = false;
  String? _originalImagePathForCropping;
  bool _isSavingCrop = false;
  bool _isSavingProduct = false; // State loading untuk tombol utama

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _codeController = TextEditingController(text: widget.initialCode ?? '');

    // Jika ada initialImageFile, set sebagai _newCroppedImageFile untuk preview
    if (widget.initialImageFile != null) {
      _newCroppedImageFile = widget.initialImageFile;
      // Tidak perlu _imageChanged atau _imageRemoved di sini, karena ini adalah state awal
    }

    _cropController = CropController(
      aspectRatio: 1.0,
      defaultCrop: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
    );
    _costPriceController.text = _formatCurrencyInput(0);
    _sellingPriceController.text = _formatCurrencyInput(0);
  }

  // ... (Fungsi _formatCurrencyInput, _parseCurrencyInput, _pickImage, _confirmCrop, _cancelCrop, _showImageSourceActionSheet, _removeCurrentImage SAMA)
  // Di _confirmCrop, _newCroppedImageFile akan di-set.
  // Di _pickImage, _newCroppedImageFile dan _originalImagePathForCropping akan di-handle.
  // Di _removeCurrentImage, _newCroppedImageFile di-null-kan, _imageRemoved = true.
  // Pastikan _clearTemporaryCroppedFile menghapus _newCroppedImageFile.
  String _formatCurrencyInput(double value) {
    final formatter = NumberFormat("#,##0", "id_ID");
    return formatter.format(value);
  }

  double _parseCurrencyInput(String text) {
    try {
      String cleanText = text.replaceAll(RegExp(r'[^\d]'), '');
      return double.tryParse(cleanText) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _stockController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _cropController.dispose();
    _clearTemporaryCroppedFile();
    // Hapus widget.initialImageFile JIKA ITU TEMPORARY dan tidak akan dipakai lagi.
    // Biasanya, provider yang memanggil screen ini sudah menghandle lifecycle file temporary.
    // if (widget.initialImageFile != null && widget.initialImageFile!.existsSync()) {
    //   widget.initialImageFile!.delete().catchError((e) => print("Error deleting initial temp file: $e"));
    // }
    super.dispose();
  }

  void _clearTemporaryCroppedFile() {
    if (_newCroppedImageFile != null && _newCroppedImageFile!.existsSync()) {
      // Jika _newCroppedImageFile adalah widget.initialImageFile, jangan hapus di sini.
      // Biarkan provider atau pemanggil yang handle.
      if (widget.initialImageFile == null ||
          widget.initialImageFile?.path != _newCroppedImageFile?.path) {
        _newCroppedImageFile!.delete().catchError((e) {
          print("Error deleting temp crop file: $e");
          return _newCroppedImageFile!;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isSavingProduct || _isCropping) return;
    setState(() {
      _isCropping = false;
      _originalImagePathForCropping = null;
      // _clearTemporaryCroppedFile(); // Hati-hati jika _newCroppedImageFile adalah initialImageFile
      if (_newCroppedImageFile != widget.initialImageFile)
        _clearTemporaryCroppedFile();
      _newCroppedImageFile = null;
    });
    try {
      final pickedFile =
          await _picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile != null) {
        setState(() {
          _originalImagePathForCropping = pickedFile.path;
          _isCropping = true;
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      UIUtils.showCustomSnackbar(context,
          message: 'Gagal memilih gambar: $e', type: SnackBarType.error);
    }
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _confirmCrop() async {
    if (_originalImagePathForCropping == null ||
        _isSavingCrop ||
        _isSavingProduct) return;
    setState(() {
      _isSavingCrop = true;
    });
    try {
      ui.Image bitmap =
          await _cropController.croppedBitmap(quality: FilterQuality.high);
      ByteData? byteData =
          await bitmap.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Tidak bisa konversi gambar.");
      Uint8List pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Buat nama file yang lebih unik untuk crop
      final filePath = '${tempDir.path}/temp_crop_add_screen_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      // Hapus file crop temporary SEBELUMNYA, kecuali jika itu initialImageFile
      if (_newCroppedImageFile != null &&
          _newCroppedImageFile != widget.initialImageFile) {
        _clearTemporaryCroppedFile();
      }

      setState(() {
        _newCroppedImageFile = file; // Ini adalah file temporary baru
        _isCropping = false;
        _originalImagePathForCropping = null;
      });
    } catch (e) {
      print("Error cropping: $e");
      UIUtils.showCustomSnackbar(context,
          message: 'Gagal memotong gambar: $e', type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _isSavingCrop = false);
    }
  }

  void _cancelCrop() {
    if (_isSavingProduct) return;
    setState(() {
      _isCropping = false;
      if (_originalImagePathForCropping != null) {
        final originalFile = File(_originalImagePathForCropping!);
        originalFile.exists().then((exists) {
          if (exists)
            originalFile.delete().catchError((e) {
              print("Error deleting original: $e");
              return originalFile;
            });
        });
        _originalImagePathForCropping = null;
      }
      // Jika batal crop, kembalikan _newCroppedImageFile ke widget.initialImageFile jika ada
      // atau null jika tidak ada initial. Ini agar preview kembali ke gambar awal (jika dari scan)
      if (widget.initialImageFile != null) {
        _newCroppedImageFile = widget.initialImageFile;
      } else {
        _newCroppedImageFile = null;
      }
    });
  }

  void _showImageSourceActionSheet(BuildContext context) {
    if (_isCropping || _isSavingProduct) return;
    UIUtils.showImageSourceActionSheet(
      context,
      onGallerySelected: () => _pickImage(ImageSource.gallery),
      onCameraSelected: () => _pickImage(ImageSource.camera),
    );
  }

  void _removeCurrentImage() {
    if (_isSavingProduct || _isCropping) return;
    setState(() {
      if (_newCroppedImageFile != widget.initialImageFile)
        _clearTemporaryCroppedFile(); // Hapus temp crop jika bukan initial
      _newCroppedImageFile = null; // Preview jadi kosong
    });
    UIUtils.showCustomSnackbar(context,
        message: 'Gambar dihapus.', type: SnackBarType.info);
  }

  // --- Logika Simpan Produk (MEMANGGIL PROVIDER) ---
  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSavingProduct) return;
    setState(() => _isSavingProduct = true);

    // Ambil ProductProvider
    final productProvider = context.read<ProductProvider>();

    final Product? savedProduct = await productProvider.addProduct(
      name: _nameController.text.trim(),
      code: _codeController.text.trim(),
      stock: int.tryParse(_stockController.text.trim()) ?? 0,
      costPrice: _parseCurrencyInput(_costPriceController.text),
      sellingPrice: _parseCurrencyInput(_sellingPriceController.text),
      // Kirim _newCroppedImageFile (bisa jadi ini adalah widget.initialImageFile jika tidak diubah, atau file crop baru)
      // Provider akan handle penyimpanan permanen.
      tempImageFile: _newCroppedImageFile,
    );

    if (!mounted) return;

    if (savedProduct != null) {
      UIUtils.showCustomSnackbar(context,
          message: 'Produk baru berhasil ditambahkan!',
          type: SnackBarType.success);
      // Jika widget.initialImageFile adalah temporary dan sudah dipakai, mungkin perlu dihapus di sini atau oleh pemanggil ProductScreen
      // Namun, karena _newCroppedImageFile yg dikirim, dan provider meng-copy-nya, file asli _newCroppedImageFile bisa dihapus
      // setelah berhasil (jika itu bukan widget.initialImageFile).
      // _clearTemporaryCroppedFile() akan menghapus _newCroppedImageFile JIKA BUKAN initial.
      if (_newCroppedImageFile != null &&
          _newCroppedImageFile != widget.initialImageFile) {
        _newCroppedImageFile!.delete().catchError((e) {
          print("Error deleting final temp add file: $e");
          return _newCroppedImageFile!;
        });
      }
      Navigator.pop(context, true); // Kirim true untuk refresh
    } else {
      // Ambil error message dari provider jika ada
      if (productProvider.errorMessage.isNotEmpty) {
        UIUtils.showCustomSnackbar(context,
            message: 'Gagal menyimpan produk: ${productProvider.errorMessage}',
            type: SnackBarType.error);
      } else {
        UIUtils.showCustomSnackbar(context,
            message: 'Gagal menyimpan produk.', type: SnackBarType.error);
      }
    }
    setState(() => _isSavingProduct = false);
  }

  // Image picker and cropping UI methods (keeping these as they are specific to this screen)

  Widget _buildImageSection() {
    return Card(
      elevation: 2,
      shadowColor: Colors.grey.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image_outlined,
                    color: Colors.grey.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Gambar Produk',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Opsional',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(child: _buildImagePicker()),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      elevation: 2,
      shadowColor: Colors.grey.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Informasi Dasar',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            CommonTextField(
              controller: _nameController,
              label: 'Nama Produk',
              hint: 'Masukkan nama produk',
              validator: (v) =>
                  v == null || v.isEmpty ? 'Nama produk wajib diisi' : null,
            ),
            CommonTextField(
              controller: _codeController,
              label: 'Kode Produk (SKU)',
              hint: 'Masukkan kode unik produk',
              validator: (v) =>
                  v == null || v.isEmpty ? 'Kode produk wajib diisi' : null,
            ),
            CommonTextField(
              controller: _stockController,
              label: 'Jumlah Stok Awal',
              hint: '0',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Jumlah stok wajib diisi';
                if (int.tryParse(v) == null) return 'Masukkan angka valid';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingSection() {
    return Card(
      elevation: 2,
      shadowColor: Colors.grey.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monetization_on_outlined,
                    color: Colors.grey.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Informasi Harga',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            CommonCurrencyField(
              controller: _costPriceController,
              label: 'Harga Modal (Beli)',
              validator: (v) {
                if (v == null || v.isEmpty) return 'Harga modal wajib diisi';
                if (_parseCurrencyInput(v) < 0) return 'Harga tidak valid';
                return null;
              },
            ),
            CommonCurrencyField(
              controller: _sellingPriceController,
              label: 'Harga Jual',
              validator: (v) {
                if (v == null || v.isEmpty) return 'Harga jual wajib diisi';
                final sell = _parseCurrencyInput(v);
                if (sell < 0) return 'Harga tidak valid';
                return null;
              },
            ),
            // Profit margin indicator
            if (_costPriceController.text.isNotEmpty &&
                _sellingPriceController.text.isNotEmpty)
              _buildProfitMarginIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitMarginIndicator() {
    final costPrice = _parseCurrencyInput(_costPriceController.text);
    final sellingPrice = _parseCurrencyInput(_sellingPriceController.text);
    final profit = sellingPrice - costPrice;
    final profitPercentage = costPrice > 0 ? (profit / costPrice) * 100 : 0.0;

    Color profitColor = Colors.grey;
    IconData profitIcon = Icons.remove;

    if (profit > 0) {
      profitColor = Colors.green;
      profitIcon = Icons.trending_up;
    } else if (profit < 0) {
      profitColor = Colors.red;
      profitIcon = Icons.trending_down;
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: profitColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: profitColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(profitIcon, color: profitColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keuntungan',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rp ${NumberFormat("#,##0", "id_ID").format(profit)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: profitColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${profitPercentage.toStringAsFixed(1)}%',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: profitColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    ImageProvider? currentImage;
    // Gunakan _newCroppedImageFile untuk preview karena ini yang akan dikirim
    if (_newCroppedImageFile != null) {
      currentImage = FileImage(_newCroppedImageFile!);
    }
    // Tidak perlu _prefilledImageFile lagi jika _newCroppedImageFile di-init dari widget.initialImageFile

    return Column(children: [
      Text("Gambar Produk (Opsional)",
          style:
              GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 15),
      InkWell(
        onTap: () => _showImageSourceActionSheet(context),
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            image: currentImage != null
                ? DecorationImage(image: currentImage, fit: BoxFit.cover)
                : null,
          ),
          child: currentImage == null
              ? Center(
                  child: Icon(Icons.add_a_photo_outlined,
                      color: Colors.grey.shade500, size: 40))
              : null,
        ),
      ),
      if (currentImage != null)
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: TextButton.icon(
            icon: Icon(Icons.delete_outline,
                color: Colors.red.shade600, size: 18),
            label: Text("Hapus Gambar",
                style: GoogleFonts.poppins(
                    color: Colors.red.shade600, fontSize: 13)),
            onPressed: _removeCurrentImage,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ),
    ]);
  }

  Widget _buildCroppingUI() {
    if (_originalImagePathForCropping == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _cancelCrop());
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
        color: Colors.black,
        child: Column(children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CropImage(
                controller: _cropController,
                key: ValueKey(_originalImagePathForCropping),
                image: Image.file(File(_originalImagePathForCropping!)),
                gridColor: Colors.white.withOpacity(0.5),
                gridCornerSize: 25,
                gridThinWidth: 1,
                gridThickWidth: 3,
                scrimColor: Colors.black.withOpacity(0.5),
                alwaysShowThirdLines: true,
                minimumImageSize: 50,
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                TextButton.icon(
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    label: const Text('Batal',
                        style: TextStyle(color: Colors.redAccent)),
                    onPressed: _isSavingCrop ? null : _cancelCrop),
                TextButton.icon(
                    icon: const Icon(Icons.check, color: Colors.green),
                    label: const Text('Konfirmasi',
                        style: TextStyle(color: Colors.green)),
                    onPressed: _isSavingCrop ? null : _confirmCrop),
              ],
            ),
          )
        ]));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isCropping && !_isSavingProduct && !_isSavingCrop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isCropping) _cancelCrop();
      },
      child: Scaffold(
        backgroundColor: AppTheme.screenBackgroundColor,
        appBar: AppBar(
          title: Text(_isCropping ? 'Potong Gambar' : 'Tambah Produk',
              style: GoogleFonts.poppins(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 22)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue.shade800,
          shadowColor: Colors.black26,
          surfaceTintColor: Colors.white,
          elevation: 0.5,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          automaticallyImplyLeading: !_isCropping && !_isSavingProduct,
          iconTheme: IconThemeData(color: Colors.blue.shade700),
          centerTitle: true,
          leading: _isCropping || _isSavingProduct ? Container() : null,
          actions: [
            UIUtils.buildGradientSaveButton(
              onPressed: (_isSavingProduct || _isCropping) ? null : _addProduct,
              isLoading: _isSavingProduct,
              text: 'Simpan',
              loadingText: 'Menyimpan...',
            ),
          ],
        ),
        body: SafeArea(
            child: Stack(children: [
          SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                  key: _formKey,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Image section
                        _buildImageSection(),
                        const SizedBox(height: 24),

                        // Basic information section
                        _buildBasicInfoSection(),
                        const SizedBox(height: 20),

                        // Pricing section
                        _buildPricingSection(), // Extra space for floating save button
                      ]))),
          if (_isCropping) _buildCroppingUI(),
          if (_isSavingCrop)
            Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                    child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white)))),
        ])),
      ),
    );
  }
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat("#,##0", "id_ID");
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    String newText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (newText.isEmpty)
      return const TextEditingValue(
          text: '', selection: TextSelection.collapsed(offset: 0));
    try {
      double value = double.parse(newText);
      String formattedText = _formatter.format(value);
      return newValue.copyWith(
          text: formattedText,
          selection: TextSelection.collapsed(offset: formattedText.length));
    } catch (e) {
      print("Error formatting number: $e");
      return oldValue;
    }
  }
}
