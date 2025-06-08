// lib/fitur/manage/product/screens/product_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:aplikasir_mobile/model/product_model.dart';
import '../providers/product_provider.dart'; // Impor Provider
import 'add_product_screen.dart';
import 'edit_product_screen.dart';
import 'barcode_scanner_screen.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/ui_utils.dart';

class ProductScreen extends StatelessWidget {
  // Ubah jadi StatelessWidget
  final int userId;
  const ProductScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProductProvider(userId: userId),
      child: const _ProductScreenContent(),
    );
  }
}

class _ProductScreenContent extends StatefulWidget {
  const _ProductScreenContent();

  @override
  State<_ProductScreenContent> createState() => _ProductScreenContentState();
}

class _ProductScreenContentState extends State<_ProductScreenContent> {
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // State _allProducts, _filteredProducts, _isLoading, _errorMessage, _isProcessingBarcode PINDAH KE PROVIDER

  @override
  void initState() {
    super.initState();
    // Listener untuk search controller
    _searchController.addListener(() {
      context.read<ProductProvider>().setSearchQuery(_searchController.text);
      // Trigger rebuild to show/hide clear button
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fungsi Load dan Filter PINDAH KE PROVIDER

  // --- Fungsi Navigasi ke Tambah Manual (DARI UI) ---
  Future<void> _navigateToAddProductManual() async {
    final provider = context.read<ProductProvider>();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider, // Pass the existing ProductProvider instance
          child: AddProductScreen(userId: provider.userId),
        ),
      ),
    );
    if (result == true && mounted) {
      provider.loadProducts();
    }
  }

  // --- Fungsi Navigasi ke Tambah dengan Data Fetch (DARI UI) ---
  Future<void> _navigateToAddProductWithData(
      FetchedProductData fetchedData) async {
    final provider = context.read<ProductProvider>();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider, // Pass the existing ProductProvider instance
          child: AddProductScreen(
            userId: provider.userId,
            initialName: fetchedData.name,
            initialCode: fetchedData.code,
            initialImageFile:
                fetchedData.imageFile, // Ini adalah temporary file
          ),
        ),
      ),
    );
    if (result == true && mounted) {
      provider.loadProducts();
    }
  }

  // --- Fungsi Tampilkan Dialog Pilihan Tambah Produk (MEMANGGIL PROVIDER) ---
  Future<void> _showAddProductOptionsDialog(
      BuildContext scaffContext, ProductProvider provider) async {
    final BuildContext currentContext =
        scaffContext; // Simpan context sebelum async
    return showDialog<void>(
      context: currentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          elevation: 5.0,
          title: Text('Tambah Produk',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18.0,
                  color: Colors.blue.shade800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pilih metode penambahan produk:',
                  style: GoogleFonts.poppins(
                      fontSize: 14.0,
                      color: Colors.grey.shade700,
                      height: 1.4)),
              const SizedBox(height: 15),
              ListTile(
                leading: Icon(Icons.edit_note,
                    color: Colors.blue.shade700, size: 30),
                title: Text('Input Manual',
                    style: GoogleFonts.poppins(
                        fontSize: 14.5, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _navigateToAddProductManual(); // Panggil dari state
                },
                contentPadding: const EdgeInsets.symmetric(vertical: 5.0),
                visualDensity: VisualDensity.compact,
              ),
              ListTile(
                leading: Icon(Icons.qr_code_scanner,
                    color: Colors.green.shade700, size: 30),
                title: Text('Scan Barcode',
                    style: GoogleFonts.poppins(
                        fontSize: 14.5, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _startRealtimeBarcodeScan(currentContext, provider);
                },
                contentPadding: const EdgeInsets.symmetric(vertical: 5.0),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    side: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Text('Batal',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500, fontSize: 14)),
            ),
          ],
        );
      },
    );
  }

  // --- Alur Scan Barcode Real-time (DARI UI, MEMANGGIL PROVIDER) ---
  Future<void> _startRealtimeBarcodeScan(
      BuildContext currentContext, ProductProvider provider) async {
    // Set loading state
    provider.setProcessingBarcode(true);

    try {
      // Navigate to real-time camera scanner with provider context
      final String? scannedBarcode = await Navigator.push<String>(
        currentContext,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: const BarcodeScannerScreen(),
          ),
        ),
      );

      if (!mounted) return;

      if (scannedBarcode != null && scannedBarcode.isNotEmpty) {
        // Process the scanned barcode
        final FetchedProductData? fetchedData =
            await provider.processBarcodeData(scannedBarcode);

        if (!mounted) return;

        if (fetchedData != null) {
          if (fetchedData.code == null &&
              fetchedData.name == null &&
              fetchedData.imageFile == null) {
            // Indikasi gagal fetch data dari API
            UIUtils.showCustomSnackbar(context,
                message: 'Data produk tidak ditemukan. Silakan input manual.',
                type: SnackBarType.info);
            await Future.delayed(const Duration(milliseconds: 500));
            _navigateToAddProductWithData(FetchedProductData(
                code: scannedBarcode, name: null, imageFile: null));
          } else {
            // Jika ada data (walaupun mungkin parsial), navigasi
            _navigateToAddProductWithData(fetchedData);
          }
        } else {
          // Jika error besar terjadi di provider
          UIUtils.showCustomSnackbar(context,
              message:
                  'Terjadi kesalahan saat memproses barcode. Silakan input manual.',
              type: SnackBarType.error);
          await Future.delayed(const Duration(milliseconds: 500));
          _navigateToAddProductWithData(FetchedProductData(
              code: scannedBarcode, name: null, imageFile: null));
        }
      } else {
        // User cancelled or no barcode detected
        UIUtils.showCustomSnackbar(context,
            message: 'Scan dibatalkan.', type: SnackBarType.info);
      }
    } catch (e) {
      if (mounted) {
        UIUtils.showCustomSnackbar(context,
            message: 'Gagal membuka scanner: $e', type: SnackBarType.error);
      }
    } finally {
      // Reset loading state
      provider.setProcessingBarcode(false);
    }
  }

  // Fungsi Ekstrak Barcode dan Fetch Data PINDAH KE PROVIDER

  // Custom snackbar methods removed - using UIUtils instead

  // --- Fungsi Navigasi ke Edit Produk (DARI UI) ---
  Future<void> _navigateToEditProduct(
      Product product, ProductProvider provider) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductScreen(initialProduct: product),
      ),
    );
    if (result == true && mounted) {
      provider.loadProducts();
    }
  }

  // --- Fungsi Hapus Produk (MEMANGGIL PROVIDER) ---
  Future<void> _deleteProduct(Product product, ProductProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content:
            Text('Anda yakin ingin menghapus produk "${product.namaProduk}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Ya, Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final success = await provider.deleteProduct(
          context, product); // Provider handle password
      if (success && mounted) {
        UIUtils.showCustomSnackbar(context,
            message: 'Produk "${product.namaProduk}" berhasil dihapus.',
            type: SnackBarType.success);
        // loadProducts sudah dipanggil di dalam provider.deleteProduct jika sukses
      } else if (!success && provider.errorMessage.isNotEmpty && mounted) {
        UIUtils.showCustomSnackbar(context,
            message: provider.errorMessage, type: SnackBarType.error);
      } else if (!success && mounted) {
        // Pesan error umum jika tidak ada dari provider (misal pembatalan password)
        // _showErrorSnackbar('Gagal menghapus produk.'); // Atau tidak tampilkan apa2 jika batal
      }
    }
  }

  // --- Helper: Build Product Card (Menggunakan data dari Provider) ---
  Widget _buildProductCard(Product product, ProductProvider provider) {
    bool isStockZero = product.jumlahProduk == 0;
    bool isLowStock = product.jumlahProduk <= 5 && product.jumlahProduk > 0;

    ImageProvider? productImage;
    if (product.gambarProduk != null && product.gambarProduk!.isNotEmpty) {
      final imageFile = File(product.gambarProduk!);
      if (imageFile.existsSync()) {
        productImage = FileImage(imageFile);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isStockZero
              ? Colors.red.withOpacity(0.3)
              : isLowStock
                  ? Colors.orange.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    color: Colors.grey[100],
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: productImage != null
                        ? Image(
                            image: productImage,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.grey[400],
                                size: 32,
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.grey[400],
                              size: 32,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.namaProduk,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          product.kodeProduk,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Stock Status
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isStockZero
                              ? Colors.red.shade50
                              : isLowStock
                                  ? Colors.orange.shade50
                                  : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isStockZero
                                ? Colors.red.shade200
                                : isLowStock
                                    ? Colors.orange.shade200
                                    : Colors.green.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isStockZero
                                  ? Icons.inventory_outlined
                                  : isLowStock
                                      ? Icons.warning_outlined
                                      : Icons.check_circle_outline,
                              size: 14,
                              color: isStockZero
                                  ? Colors.red.shade600
                                  : isLowStock
                                      ? Colors.orange.shade600
                                      : Colors.green.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isStockZero
                                  ? 'Stok Habis'
                                  : isLowStock
                                      ? 'Stok Menipis (${product.jumlahProduk})'
                                      : 'Stok: ${product.jumlahProduk}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: isStockZero
                                    ? Colors.red.shade600
                                    : isLowStock
                                        ? Colors.orange.shade600
                                        : Colors.green.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Price Information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildPriceInfo(
                      'Harga Modal',
                      product.hargaModal,
                      Colors.orange.shade600,
                      Icons.attach_money_outlined,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPriceInfo(
                      'Harga Jual',
                      product.hargaJual,
                      Colors.green.shade600,
                      Icons.sell_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _navigateToEditProduct(product, provider),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(
                        'Edit',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: () => _deleteProduct(product, provider),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(
                        'Hapus',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade500,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceInfo(
      String label, double price, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          currencyFormatter.format(price),
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // Add statistics section method with filtering functionality
  Widget _buildStatisticsSection(ProductProvider provider) {
    // Calculate stats from all products (not filtered ones for accurate counts)
    final allProducts = provider.allProducts; // Use the correct getter
    final totalProducts = allProducts.length;
    final outOfStockProducts =
        allProducts.where((p) => p.jumlahProduk == 0).length;
    final lowStockProducts = allProducts
        .where((p) => p.jumlahProduk > 0 && p.jumlahProduk <= 5)
        .length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total',
              totalProducts.toString(),
              Icons.inventory_2_outlined,
              Colors.blue.shade600,
              Colors.blue.shade50,
              isSelected: provider.stockFilter == 'all',
              onTap: () => provider.setStockFilter('all'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Stok Rendah',
              lowStockProducts.toString(),
              Icons.warning_outlined,
              Colors.orange.shade600,
              Colors.orange.shade50,
              isSelected: provider.stockFilter == 'low_stock',
              onTap: () => provider.setStockFilter('low_stock'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Stok Habis',
              outOfStockProducts.toString(),
              Icons.inventory_outlined,
              Colors.red.shade600,
              Colors.red.shade50,
              isSelected: provider.stockFilter == 'out_of_stock',
              onTap: () => provider.setStockFilter('out_of_stock'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      Color backgroundColor,
      {bool isSelected = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isSelected ? color : color.withOpacity(0.2),
              width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(60),
                border: Border.all(color: Colors.blue.shade100, width: 2),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 60,
                color: Colors.blue.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum Ada Produk',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mulai kelola toko Anda dengan\nmenambahkan produk pertama',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => _showAddProductOptionsDialog(
                    context, context.read<ProductProvider>()),
                icon: const Icon(Icons.add, size: 20),
                label: Text(
                  'Tambah Produk',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.grey.shade200, width: 2),
              ),
              child: Icon(
                Icons.search_off_outlined,
                size: 50,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Produk Tidak Ditemukan',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coba ubah kata kunci pencarian\natau periksa ejaan',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.red.shade200, width: 2),
              ),
              child: Icon(
                Icons.error_outline,
                size: 50,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Terjadi Kesalahan',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 140,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () => context.read<ProductProvider>().loadProducts(),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  'Coba Lagi',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider =
        context.watch<ProductProvider>(); // Dapatkan provider

    return Scaffold(
      backgroundColor: AppTheme.screenBackgroundColor,
      appBar: AppBar(
        title: Text('Kelola Produk',
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
        automaticallyImplyLeading: true,
        iconTheme: IconThemeData(color: Colors.blue.shade700),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: productProvider.isProcessingBarcode
                ? null
                : () => _showAddProductOptionsDialog(context, productProvider),
            icon: productProvider.isProcessingBarcode
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.blue.shade600,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    Icons.add,
                    color: Colors.blue.shade600,
                    size: 26,
                  ),
            tooltip: 'Tambah Produk',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.0),
              child: Row(children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.0),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 1))
                        ]),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari nama atau kode produk...',
                        hintStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade600, fontSize: 14),
                        prefixIcon: Icon(Icons.search,
                            color: Colors.grey.shade600, size: 22),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    color: Colors.grey.shade500, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  productProvider.setSearchQuery('');
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 14.0, horizontal: 5),
                        isDense: true,
                      ),
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: Colors.black87),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => productProvider.toggleSortOrder(),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.0),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 1))
                        ]),
                    child: Tooltip(
                      message: productProvider.sortAscending
                          ? 'Urutkan Z-A'
                          : 'Urutkan A-Z',
                      child: Icon(Icons.sort_by_alpha,
                          color: Colors.blue.shade600, size: 24),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            // Filter/Statistics Cards (smaller, below search)
            _buildStatisticsSection(productProvider),
            const SizedBox(height: 20),
            Expanded(
              child: productProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : productProvider.errorMessage.isNotEmpty
                      ? _buildErrorState(productProvider.errorMessage)
                      : productProvider.filteredProducts.isEmpty &&
                              productProvider.searchQuery
                                  .isEmpty // Cek apakah semua produk kosong (sebelum filter)
                          ? _buildEmptyState()
                          : productProvider
                                  .filteredProducts.isEmpty // Cek hasil filter
                              ? _buildNoSearchResults()
                              : RefreshIndicator(
                                  onRefresh: () =>
                                      productProvider.loadProducts(),
                                  child: ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemCount:
                                        productProvider.filteredProducts.length,
                                    itemBuilder: (context, index) {
                                      return _buildProductCard(
                                          productProvider
                                              .filteredProducts[index],
                                          productProvider);
                                    },
                                  ),
                                ),
            ),
          ],
        ),
      ),
    );
  }
}
