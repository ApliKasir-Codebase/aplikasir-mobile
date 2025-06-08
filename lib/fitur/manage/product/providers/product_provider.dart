// lib/fitur/manage/product/providers/product_provider.dart
import 'dart:io';
import 'dart:convert'; // Untuk jsonDecode
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Untuk OpenFoodFacts
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:aplikasir_mobile/model/product_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';

// Definisikan FetchedProductData di sini atau impor dari path yang benar
class FetchedProductData {
  final String? name;
  final String? code;
  final File? imageFile; // Ini akan jadi temporary file
  FetchedProductData({this.name, this.code, this.imageFile});
}

class ProductProvider extends ChangeNotifier {
  final int userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final BarcodeScanner _barcodeScanner = BarcodeScanner(formats: [
    BarcodeFormat.qrCode,
    BarcodeFormat.ean13,
    BarcodeFormat.upca,
    BarcodeFormat.code128
  ]); // Tambah format lain

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _sortAscending = true; // Default A-Z by name
  String _searchQuery = '';
  bool _isProcessingBarcode = false;
  String _stockFilter = 'all'; // all, low_stock, out_of_stock
  // Getters
  List<Product> get filteredProducts => _filteredProducts;
  List<Product> get allProducts => _allProducts;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get sortAscending => _sortAscending;
  String get searchQuery => _searchQuery;
  bool get isProcessingBarcode => _isProcessingBarcode;
  String get stockFilter => _stockFilter;

  ProductProvider({required this.userId}) {
    loadProducts();
  }

  @override
  void dispose() {
    _barcodeScanner.close();
    super.dispose();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      _allProducts = await _dbHelper.getProductsByUserId(userId);
      _applyFiltersAndSort();
    } catch (e) {
      _errorMessage = 'Gagal memuat produk: ${e.toString()}';
      _allProducts = [];
      _filteredProducts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase().trim();
    _applyFiltersAndSort();
  }

  void toggleSortOrder() {
    _sortAscending = !_sortAscending;
    _applyFiltersAndSort();
  }

  void setStockFilter(String filter) {
    _stockFilter = filter;
    _applyFiltersAndSort();
  }

  void setProcessingBarcode(bool processing) {
    _isProcessingBarcode = processing;
    notifyListeners();
  }

  // New method to process barcode data (separated from camera handling)
  Future<FetchedProductData?> processBarcodeData(String barcodeValue) async {
    _isProcessingBarcode = true;
    notifyListeners();
    try {
      // Try to fetch product data from API
      final fetchedApiData = await _fetchProductDataFromApi(barcodeValue);
      File? downloadedImageFile;

      if (fetchedApiData != null &&
          fetchedApiData['imageUrl'] != null &&
          fetchedApiData['imageUrl'].toString().isNotEmpty) {
        final imageUrl = fetchedApiData['imageUrl'];
        if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
          final tempFile = await _downloadImage(imageUrl, barcodeValue);
          if (tempFile != null && await tempFile.exists()) {
            downloadedImageFile = tempFile;
          }
        } else {
          final localFile = File(imageUrl);
          if (await localFile.exists()) {
            downloadedImageFile = localFile;
          }
        }
      }

      return FetchedProductData(
        name: fetchedApiData?['name'],
        code: barcodeValue,
        imageFile: downloadedImageFile,
      );
    } catch (e) {
      _errorMessage = "Error processing barcode: e.toString()}";
      return FetchedProductData(
        code: barcodeValue,
        name: null,
        imageFile: null,
      );
    } finally {
      _isProcessingBarcode = false;
      notifyListeners();
    }
  }

  void _applyFiltersAndSort() {
    List<Product> tempFiltered = List.from(_allProducts);

    if (_searchQuery.isNotEmpty) {
      tempFiltered = tempFiltered.where((product) {
        final nameLower = product.namaProduk.toLowerCase();
        final codeLower = product.kodeProduk.toLowerCase();
        return nameLower.contains(_searchQuery) ||
            codeLower.contains(_searchQuery);
      }).toList();
    }

    if (_stockFilter == 'low_stock') {
      tempFiltered =
          tempFiltered.where((product) => product.jumlahProduk < 10).toList();
    } else if (_stockFilter == 'out_of_stock') {
      tempFiltered =
          tempFiltered.where((product) => product.jumlahProduk == 0).toList();
    }

    tempFiltered.sort((a, b) {
      int comparison =
          a.namaProduk.toLowerCase().compareTo(b.namaProduk.toLowerCase());
      return _sortAscending ? comparison : -comparison;
    });

    _filteredProducts = tempFiltered;
    notifyListeners();
  }

  // --- Helper untuk menyimpan gambar ke storage permanen lokal ---
  Future<String?> _saveImageToPermanentLocation(File tempImageFile,
      {required int userId, int? localProductIdForName}) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(
          p.join(documentsDir.path, 'product_images', userId.toString()));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final String fileName = localProductIdForName != null
          ? 'prod_${localProductIdForName}_$timestamp.png'
          : 'new_prod_${userId}_$timestamp.png';
      final permanentPath = p.join(imagesDir.path, fileName);
      final permanentFile = await tempImageFile.copy(permanentPath);
      print("Image saved to permanent location: ${permanentFile.path}");
      return permanentFile.path;
    } catch (e) {
      print("Error saving image to permanent location: $e");
      return null;
    }
  }

  // --- Helper untuk menghapus gambar lokal ---
  Future<void> _deleteLocalImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        print("Deleted local image: $imagePath");
      }
    } catch (e) {
      print("Error deleting local image $imagePath: $e");
    }
  }

  Future<Product?> addProduct({
    required String name,
    required String code,
    required int stock,
    required double costPrice,
    required double sellingPrice,
    File?
        tempImageFile, // Temporary file from AddProductScreen's picker/cropper
  }) async {
    _isLoading = true; // Bisa juga pakai flag loading lain untuk aksi ini
    _errorMessage = '';
    notifyListeners();

    String? finalLocalImagePath;
    if (tempImageFile != null) {
      // Debug print
      print('AddProduct: tempImageFile path: ${tempImageFile.path}');
      finalLocalImagePath =
          await _saveImageToPermanentLocation(tempImageFile, userId: userId);
      // Debug print
      print('AddProduct: saved image to: $finalLocalImagePath');
      if (finalLocalImagePath == null) {
        _errorMessage = "Gagal menyimpan gambar produk.";
        _isLoading = false;
        notifyListeners();
        return null;
      }
    }

    final newProduct = Product(
      idPengguna: userId,
      namaProduk: name,
      kodeProduk: code,
      jumlahProduk: stock,
      hargaModal: costPrice,
      hargaJual: sellingPrice,
      gambarProduk: finalLocalImagePath,
      createdAt: DateTime.now(), // Set created_at
      updatedAt: DateTime.now(), // Set updated_at
      syncStatus: 'new',
    );

    try {
      final productId = await _dbHelper.insertProductLocal(newProduct);
      await loadProducts(); // Reload list
      _isLoading = false;
      notifyListeners();
      return newProduct.copyWith(id: productId); // Kembalikan dengan ID lokal
    } catch (e) {
      print('AddProduct: error inserting product: $e');
      _errorMessage = "Gagal menambah produk: ${e.toString()}";
      if (finalLocalImagePath != null)
        await _deleteLocalImage(finalLocalImagePath);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<Product?> updateProduct({
    required Product existingProduct,
    required String name,
    required String code,
    required int stock,
    required double costPrice,
    required double sellingPrice,
    File? tempNewImageFile, // Temporary file from EditProductScreen
    bool imageWasRemovedByUser = false, // Dari EditProductScreen
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    String? finalLocalImagePath = existingProduct.gambarProduk;

    if (imageWasRemovedByUser) {
      if (existingProduct.gambarProduk != null) {
        await _deleteLocalImage(existingProduct.gambarProduk!);
      }
      finalLocalImagePath = null;
    } else if (tempNewImageFile != null) {
      // Ada gambar baru, hapus yang lama (jika ada), simpan yang baru
      if (existingProduct.gambarProduk != null) {
        await _deleteLocalImage(existingProduct.gambarProduk!);
      }
      finalLocalImagePath = await _saveImageToPermanentLocation(
          tempNewImageFile,
          userId: userId,
          localProductIdForName: existingProduct.id);
      if (finalLocalImagePath == null) {
        _errorMessage = "Gagal menyimpan gambar baru.";
        _isLoading = false;
        notifyListeners();
        return null;
      }
    }

    final updatedProduct = existingProduct.copyWith(
      namaProduk: name,
      kodeProduk: code,
      jumlahProduk: stock,
      hargaModal: costPrice,
      hargaJual: sellingPrice,
      gambarProduk: finalLocalImagePath,
      setGambarProdukNull: imageWasRemovedByUser, // Untuk model
      updatedAt: DateTime.now(),
      syncStatus: (existingProduct.syncStatus == 'new') ? 'new' : 'updated',
    );

    try {
      await _dbHelper.updateProductLocal(updatedProduct);
      await loadProducts(); // Reload list
      _isLoading = false;
      notifyListeners();
      return updatedProduct;
    } catch (e) {
      _errorMessage = "Gagal memperbarui produk: ${e.toString()}";
      // Jika gambar baru gagal disimpan ke DB, mungkin perlu rollback gambar baru yg sudah disimpan permanen
      // Tapi ini kompleks, untuk saat ini biarkan.
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteProduct(BuildContext context, Product product) async {
    // Direct delete without password confirmation
    if (product.id == null) {
      _errorMessage = "ID Produk tidak valid untuk dihapus.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Hapus gambar lokal jika ada
      if (product.gambarProduk != null) {
        await _deleteLocalImage(product.gambarProduk!);
      }
      // Hapus dari database (soft delete)
      await _dbHelper.softDeleteProductLocal(product.id!, userId);
      await loadProducts();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "Gagal menghapus produk: ${e.toString()}";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- Barcode Scanning Flow ---
  Future<FetchedProductData?> startBarcodeScanFlow(
      BuildContext context, ImageSource source) async {
    _isProcessingBarcode = true;
    notifyListeners();
    FetchedProductData? resultData;

    try {
      final XFile? pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile == null) {
        _isProcessingBarcode = false;
        notifyListeners();
        return null;
      }
      final File imageFile = File(pickedFile.path);
      final barcodeValue = await _extractBarcodeFromImage(imageFile);

      if (barcodeValue == null) {
        _isProcessingBarcode = false;
        notifyListeners();
        return FetchedProductData(code: null, name: null, imageFile: null);
      }
      final fetchedApiData = await _fetchProductDataFromApi(barcodeValue);
      File? downloadedImageFile;
      if (fetchedApiData != null &&
          fetchedApiData['imageUrl'] != null &&
          fetchedApiData['imageUrl'].toString().isNotEmpty) {
        final imageUrl = fetchedApiData['imageUrl'];
        if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
          final tempFile = await _downloadImage(imageUrl, barcodeValue);
          if (tempFile != null && await tempFile.exists()) {
            downloadedImageFile = tempFile;
          }
        } else {
          final localFile = File(imageUrl);
          if (await localFile.exists()) {
            downloadedImageFile = localFile;
          }
        }
      }

      resultData = FetchedProductData(
        name: fetchedApiData?['name'],
        code: barcodeValue,
        imageFile: downloadedImageFile,
      );
    } catch (e) {
      _errorMessage = "Error saat scan: ${e.toString()}";
      resultData = FetchedProductData(code: null, name: null, imageFile: null);
    } finally {
      _isProcessingBarcode = false;
      notifyListeners();
    }
    return resultData;
  }

  Future<String?> _extractBarcodeFromImage(File imageFile) async {
    try {
      final InputImage inputImage = InputImage.fromFilePath(imageFile.path);
      final List<Barcode> barcodes =
          await _barcodeScanner.processImage(inputImage);
      if (barcodes.isNotEmpty) {
        Barcode? selectedBarcode;
        for (var barcode in barcodes) {
          if (barcode.format == BarcodeFormat.ean13 ||
              barcode.format == BarcodeFormat.upca) {
            selectedBarcode = barcode;
            break;
          }
        }
        selectedBarcode ??= barcodes.firstWhere(
            (b) => b.rawValue != null && b.rawValue!.isNotEmpty,
            orElse: () => barcodes.first);
        return selectedBarcode.rawValue;
      }
      return null;
    } catch (e) {
      print("Error extracting barcode: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchProductDataFromApi(String barcode) async {
    // Check if product already exists locally first
    final existingProduct = _allProducts.firstWhere(
      (product) => product.kodeProduk == barcode,
      orElse: () => Product(
        idPengguna: userId,
        namaProduk: '',
        kodeProduk: '',
        jumlahProduk: 0,
        hargaModal: 0.0,
        hargaJual: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // If product exists locally, return its data
    if (existingProduct.kodeProduk.isNotEmpty) {
      return {
        'name': existingProduct.namaProduk,
        'imageUrl': existingProduct.gambarProduk,
        'costPrice': existingProduct.hargaModal,
        'sellingPrice': existingProduct.hargaJual,
        'stock': existingProduct.jumlahProduk,
      };
    }

    // If not found locally, try OpenFoodFacts API as fallback for EAN/UPC codes
    if (_isValidEanUpc(barcode)) {
      try {
        final url = Uri.parse(
            'https://world.openfoodfacts.org/api/v0/product/$barcode.json');
        final response = await http.get(
          url,
          headers: {'User-Agent': 'ApliKasir/1.0'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 1 && data['product'] != null) {
            final product = data['product'];
            return {
              'name': product['product_name'] ??
                  'Produk ${barcode.substring(barcode.length - 4)}',
              'imageUrl': product['image_url'],
              'costPrice': null, // Will be filled by user
              'sellingPrice': null, // Will be filled by user
              'stock': null, // Will be filled by user
            };
          }
        }
      } catch (e) {
        print('Error fetching from OpenFoodFacts: $e');
      }
    }

    // Return null if no data found anywhere
    return null;
  }

  bool _isValidEanUpc(String barcode) {
    // Check if barcode is EAN-13, EAN-8, or UPC-A format
    if (barcode.length == 13 || barcode.length == 8 || barcode.length == 12) {
      return RegExp(r'^\d+$').hasMatch(barcode);
    }
    return false;
  }

  Future<File?> _downloadImage(String imageUrl, String barcode) async {
    try {
      final response = await http
          .get(Uri.parse(imageUrl), headers: {'User-Agent': 'ApliKasir/1.0'});
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        // Buat nama file yang lebih unik untuk menghindari konflik jika barcode sama discan berulang kali
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath =
            p.join(tempDir.path, 'temp_dl_prod_img_${barcode}_$timestamp.png');
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
      return null;
    } catch (e) {
      print("Error downloading image: $e");
      return null;
    }
  }
}
