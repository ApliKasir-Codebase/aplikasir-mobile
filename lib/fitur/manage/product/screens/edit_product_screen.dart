// lib/fitur/manage/product/edit_product_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_image/crop_image.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:aplikasir_mobile/model/product_model.dart';
import 'package:aplikasir_mobile/fitur/manage/product/providers/product_provider.dart';
import 'package:aplikasir_mobile/theme/app_theme.dart';
import 'package:aplikasir_mobile/utils/ui_utils.dart';
import 'package:aplikasir_mobile/widgets/common_widgets.dart';

class EditProductScreen extends StatefulWidget {
  final Product initialProduct;

  const EditProductScreen({super.key, required this.initialProduct});

  @override
  _EditProductScreenState createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  late CropController _cropController;

  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _stockController;
  late TextEditingController _costPriceController;
  late TextEditingController _sellingPriceController;

  File? _newCroppedImageFile; // File temporary hasil crop BARU
  String? _initialSavedImagePath; // Path gambar LAMA yang tersimpan
  bool _imageChangedOrRemoved =
      false; // Flag jika gambar baru dipilih ATAU gambar lama dihapus

  bool _isCropping = false;
  String? _originalImagePathForCropping;
  bool _isSavingCrop = false;
  bool _isSavingProduct = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.initialProduct.namaProduk);
    _codeController =
        TextEditingController(text: widget.initialProduct.kodeProduk);
    _stockController = TextEditingController(
        text: widget.initialProduct.jumlahProduk.toString());
    _costPriceController = TextEditingController(
        text: _formatCurrencyInput(widget.initialProduct.hargaModal));
    _sellingPriceController = TextEditingController(
        text: _formatCurrencyInput(widget.initialProduct.hargaJual));
    _initialSavedImagePath =
        widget.initialProduct.gambarProduk; // Simpan path gambar awal

    _cropController = CropController(
        aspectRatio: 1.0, defaultCrop: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9));
  }

  // ... (Fungsi _formatCurrencyInput, _parseCurrencyInput, _pickImage, _confirmCrop, _cancelCrop, _showImageSourceActionSheet SAMA seperti AddProductScreen)
  // Penyesuaian kecil di _pickImage, _confirmCrop, _cancelCrop untuk _imageChangedOrRemoved dan _initialSavedImagePath
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
    _clearTemporaryCroppedFileOnly(); // Hanya hapus _newCroppedImageFile jika itu temporary
    super.dispose();
  }

  // Hanya hapus _newCroppedImageFile jika BUKAN file asli yang sudah ada
  void _clearTemporaryCroppedFileOnly() {
    if (_newCroppedImageFile != null && _newCroppedImageFile!.existsSync()) {
      // Jangan hapus jika _newCroppedImageFile adalah _initialSavedImagePath (belum di-crop ulang)
      if (_newCroppedImageFile!.path != _initialSavedImagePath) {
        _newCroppedImageFile!.delete().catchError((e) {
          print("Error deleting temp edit crop file: $e");
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
      _clearTemporaryCroppedFileOnly(); // Hanya hapus file crop temp baru
      _newCroppedImageFile = null; // Reset file crop baru
      _imageChangedOrRemoved =
          false; // Awalnya false, akan jadi true jika ada crop/remove
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
      _showErrorSnackbar('Gagal memilih gambar: $e');
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
      final filePath = '${tempDir.path}/temp_crop_edit_screen_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      _clearTemporaryCroppedFileOnly(); // Hapus file crop temp lama (jika ada & beda)

      setState(() {
        _newCroppedImageFile = file; // File crop baru siap (temporary)
        _isCropping = false;
        _originalImagePathForCropping = null;
        _imageChangedOrRemoved = true; // Gambar telah diubah
      });
    } catch (e) {
      print("Error cropping: $e");
      _showErrorSnackbar('Gagal memotong gambar: $e');
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
          if (exists) {
            originalFile.delete().catchError((e) {
              print("Error deleting original: $e");
              return originalFile;
            });
          }
        });
        _originalImagePathForCropping = null;
      }
      // Saat batal crop, _newCroppedImageFile tidak diubah, biarkan preview gambar lama (jika ada)
      // atau kosong jika memang belum ada gambar baru. _imageChangedOrRemoved juga tidak diubah di sini.
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
      _clearTemporaryCroppedFileOnly(); // Hapus file crop temp baru jika ada
      _newCroppedImageFile = null; // Tidak ada preview gambar baru
      _imageChangedOrRemoved = true; // Gambar dianggap diubah (menjadi null)
    });
    _showInfoSnackbar('Gambar akan dihapus saat disimpan.');
  }

  // --- Logika Simpan Perubahan (MEMANGGIL PROVIDER) ---
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSavingProduct) return;
    setState(() => _isSavingProduct = true);

    final productProvider = context.read<ProductProvider>();

    final Product? savedProduct = await productProvider.updateProduct(
      existingProduct: widget.initialProduct,
      name: _nameController.text.trim(),
      code: _codeController.text.trim(),
      stock: int.tryParse(_stockController.text.trim()) ?? 0,
      costPrice: _parseCurrencyInput(_costPriceController.text),
      sellingPrice: _parseCurrencyInput(_sellingPriceController.text),
      // Kirim _newCroppedImageFile jika ada perubahan, provider akan handle
      tempNewImageFile: _imageChangedOrRemoved ? _newCroppedImageFile : null,
      imageWasRemovedByUser: _imageChangedOrRemoved &&
          _newCroppedImageFile == null, // Jika diubah jadi null
    );

    if (!mounted) return;

    if (savedProduct != null) {
      _showSuccessSnackbar('Produk berhasil diperbarui!');
      // File temporary _newCroppedImageFile (jika ada dan BUKAN file awal) akan dihapus oleh provider setelah disimpan permanen
      Navigator.pop(context, true); // Kirim true untuk refresh
    } else {
      if (productProvider.errorMessage.isNotEmpty) {
        _showErrorSnackbar(
            'Gagal memperbarui produk: ${productProvider.errorMessage}');
      } else {
        _showErrorSnackbar('Gagal memperbarui produk.');
      }
    }
    setState(() => _isSavingProduct = false);
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    UIUtils.showCustomSnackbar(
      context,
      message: message,
      type: SnackBarType.error,
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    UIUtils.showCustomSnackbar(
      context,
      message: message,
      type: SnackBarType.success,
    );
  }

  void _showInfoSnackbar(String message) {
    if (!mounted) return;
    UIUtils.showCustomSnackbar(
      context,
      message: message,
      type: SnackBarType.info,
    );
  }

  // --- Widget UI SAMA seperti AddProductScreen ---
  // (_buildImagePicker, _buildCroppingUI)
  // Perbedaannya hanya pada teks tombol utama menjadi "Simpan Perubahan"

  Widget _buildImagePicker() {
    ImageProvider? currentImageProvider;
    // Prioritaskan _newCroppedImageFile jika ada (hasil crop baru)
    if (_newCroppedImageFile != null) {
      currentImageProvider = FileImage(_newCroppedImageFile!);
    }
    // Jika tidak ada crop baru DAN gambar belum ditandai hapus (_imageChangedOrRemoved belum true atau true tapi _newCroppedImageFile masih ada),
    // DAN ada path gambar awal, tampilkan gambar awal.
    else if (!_imageChangedOrRemoved &&
        _initialSavedImagePath != null &&
        File(_initialSavedImagePath!).existsSync()) {
      currentImageProvider = FileImage(File(_initialSavedImagePath!));
    }
    // Jika _imageChangedOrRemoved true DAN _newCroppedImageFile null, berarti gambar dihapus, currentImageProvider tetap null.

    return Column(children: [
      // Image container with modern design
      Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showImageSourceActionSheet(context),
            child: Container(
              decoration: BoxDecoration(
                color: currentImageProvider == null
                    ? Colors.grey.shade50
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: currentImageProvider == null
                      ? Colors.grey.shade300
                      : Colors.grey.shade200,
                  width: currentImageProvider == null ? 2 : 1,
                  style: currentImageProvider == null
                      ? BorderStyle.solid
                      : BorderStyle.solid,
                ),
                image: currentImageProvider != null
                    ? DecorationImage(
                        image: currentImageProvider, fit: BoxFit.cover)
                    : null,
              ),
              child: currentImageProvider == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            color: Colors.blue.shade600,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tambah Gambar',
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ketuk untuk memilih',
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      children: [
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.edit,
                              color: Colors.grey.shade600,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),

      const SizedBox(height: 16),

      // Action buttons
      if (currentImageProvider != null)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Edit button
            TextButton.icon(
              icon: Icon(Icons.edit_outlined,
                  color: Colors.blue.shade600, size: 18),
              label: Text(
                "Edit Gambar",
                style: GoogleFonts.poppins(
                  color: Colors.blue.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () => _showImageSourceActionSheet(context),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Delete button
            TextButton.icon(
              icon: Icon(Icons.delete_outline,
                  color: Colors.red.shade600, size: 18),
              label: Text(
                "Hapus Gambar",
                style: GoogleFonts.poppins(
                  color: Colors.red.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: _removeCurrentImage,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        )
      else
        // Help text when no image
        Text(
          'Gambar produk membantu pelanggan mengenali produk dengan lebih mudah',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.grey.shade500,
            fontSize: 12,
            height: 1.4,
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
          // Header with instructions
          Container(
            color: Colors.black.withOpacity(0.8),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.crop, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Potong Gambar',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Seret dan sesuaikan area yang ingin dipotong',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Crop area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CropImage(
                controller: _cropController,
                key: ValueKey(_originalImagePathForCropping),
                image: Image.file(File(_originalImagePathForCropping!)),
                gridColor: Colors.white.withOpacity(0.7),
                gridCornerSize: 30,
                gridThinWidth: 1,
                gridThickWidth: 3,
                scrimColor: Colors.black.withOpacity(0.6),
                alwaysShowThirdLines: true,
                minimumImageSize: 50,
              ),
            ),
          ),

          // Action buttons
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: <Widget>[
                // Cancel button
                Expanded(
                  child: Container(
                    height: 48,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSavingCrop ? null : _cancelCrop,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Batal',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Confirm button
                Expanded(
                  child: Container(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: Colors.blue.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSavingCrop ? null : _confirmCrop,
                      child: _isSavingCrop
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Konfirmasi',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
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
          title: Text(_isCropping ? 'Potong Gambar' : 'Edit Produk',
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
              onPressed:
                  (_isSavingProduct || _isCropping) ? null : _saveProduct,
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
              label: 'Jumlah Stok',
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
