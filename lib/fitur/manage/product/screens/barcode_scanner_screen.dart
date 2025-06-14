import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import 'package:provider/provider.dart';
import 'package:aplikasir_mobile/fitur/manage/product/providers/product_provider.dart';
import 'package:aplikasir_mobile/fitur/homepage/providers/homepage_provider.dart';
import 'package:aplikasir_mobile/model/product_model.dart';
import 'package:aplikasir_mobile/theme/app_theme.dart';
import 'package:aplikasir_mobile/fitur/checkout/providers/checkout_providers.dart';
import 'package:aplikasir_mobile/fitur/checkout/screens/checkout_screen.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final bool returnOnScan;
  final bool checkoutFlow;
  const BarcodeScannerScreen(
      {super.key, this.returnOnScan = false, this.checkoutFlow = false});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isDetecting = false;
  bool _isFlashOn = false;
  String? _scannedBarcode;
  Timer? _scanTimer;
  DateTime? _blockedUntil;

  final BarcodeScanner _barcodeScanner = BarcodeScanner(
    formats: [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upca,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.codabar,
      BarcodeFormat.itf,
      BarcodeFormat.qrCode,
    ],
  );

  // Pending products for cart
  final List<PendingProduct> _pendingProducts = [];

  // checkoutFlow accumulation list
  // For continuous checkout scanning
  final List<Product> _checkoutScanned = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _barcodeScanner.close();
    _scanTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showError('Tidak ada kamera yang tersedia');
        return;
      }

      final camera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      // Try different configurations for better compatibility
      await _initializeCameraWithFallback(camera);

      if (mounted && _cameraController?.value.isInitialized == true) {
        setState(() {});
        _startImageStream();
      }
    } catch (e) {
      _showError('Gagal menginisialisasi kamera: $e');
    }
  }

  Future<void> _initializeCameraWithFallback(CameraDescription camera) async {
    // Configuration attempts in order of preference
    final configs = [
      {
        'resolution': ResolutionPreset.medium,
        'format': Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      },
      {
        'resolution': ResolutionPreset.low,
        'format': Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      },
      {
        'resolution': ResolutionPreset.medium,
        'format': Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      },
      // Fallback to BGRA8888 for maximum compatibility
      {
        'resolution': ResolutionPreset.medium,
        'format': ImageFormatGroup.bgra8888,
      },
    ];

    for (var config in configs) {
      try {
        _cameraController?.dispose();
        _cameraController = CameraController(
          camera,
          config['resolution'] as ResolutionPreset,
          enableAudio: false,
          imageFormatGroup: config['format'] as ImageFormatGroup,
        );

        await _cameraController!.initialize();
        // format stored in controller; no need to keep in state
        print(
            'Camera initialized with resolution: ${config['resolution']}, format: ${config['format']}');
        return; // Success
      } catch (e) {
        print('Failed to initialize camera with config $config: $e');
        continue; // Try next configuration
      }
    }

    throw Exception('Failed to initialize camera with any configuration');
  }

  void _startImageStream() {
    if (_cameraController?.value.isInitialized == true) {
      _cameraController!.startImageStream(_processCameraImage);
    }
  }

  void _processCameraImage(CameraImage image) {
    if (_isDetecting || _scannedBarcode != null) return;

    _isDetecting = true;

    _detectBarcode(image).then((barcode) {
      if (barcode != null && _scannedBarcode == null) {
        _scannedBarcode = barcode;
        _onBarcodeDetected(barcode);
      }
      _isDetecting = false;
    }).catchError((error) {
      _isDetecting = false;
    });
  }

  Future<String?> _detectBarcode(CameraImage image) async {
    try {
      InputImage? inputImage;
      if (Platform.isAndroid) {
        inputImage = _buildAndroidInputImage(image);
      } else {
        inputImage = _buildIOSInputImage(image);
      }
      if (inputImage == null) return null;
      final List<Barcode> barcodes =
          await _barcodeScanner.processImage(inputImage);
      if (barcodes.isNotEmpty) {
        // Prioritize EAN13 and UPCA barcodes
        Barcode? selected;
        for (var b in barcodes) {
          if (b.format == BarcodeFormat.ean13 ||
              b.format == BarcodeFormat.upca) {
            selected = b;
            break;
          }
        }
        selected ??= barcodes.firstWhere(
            (b) => b.rawValue != null && b.rawValue!.isNotEmpty,
            orElse: () => barcodes.first);
        return selected.rawValue;
      }
      return null;
    } catch (e) {
      print('Error detecting barcode: $e');
      return null;
    }
  }

  InputImage? _buildAndroidInputImage(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final Plane yPlane = image.planes[0];
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel!;

      // NV21 format buffer size: width*height (Y) + 2*(width/2)*(height/2) (VU)
      final int bufferSize = width * height * 3 ~/ 2;
      final Uint8List nv21Bytes = Uint8List(bufferSize);
      int offset = 0;

      // Copy Y plane
      for (int row = 0; row < height; row++) {
        final int rowStart = row * yPlane.bytesPerRow;
        nv21Bytes.setRange(offset, offset + width, yPlane.bytes, rowStart);
        offset += width;
      }

      // Interleave V and U for NV21
      for (int row = 0; row < height ~/ 2; row++) {
        final int uvRowStart = row * uvRowStride;
        for (int col = 0; col < width ~/ 2; col++) {
          final int uvIndex = uvRowStart + col * uvPixelStride;
          nv21Bytes[offset++] = vPlane.bytes[uvIndex];
          nv21Bytes[offset++] = uPlane.bytes[uvIndex];
        }
      }

      // Construct InputImage
      final Size imageSize = Size(width.toDouble(), height.toDouble());
      final InputImageRotation rotation = InputImageRotationValue.fromRawValue(
            _cameras[0].sensorOrientation,
          ) ??
          InputImageRotation.rotation0deg;

      return InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: width,
        ),
      );
    } catch (e) {
      print('Error building Android InputImage: $e');
      return null;
    }
  }

  InputImage? _buildIOSInputImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();
      final Size imageSize =
          Size(image.width.toDouble(), image.height.toDouble());
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } catch (e) {
      print('Error building iOS InputImage: $e');
      return null;
    }
  }

  void _showCustomSnackBar(String message, {bool isError = false}) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: isError ? Colors.red.shade700 : Colors.green.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: Colors.white,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      elevation: 6,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _onBarcodeDetected(String barcode) async {
    // Return immediately if configured
    if (widget.returnOnScan) {
      Navigator.of(context).pop(barcode);
      return;
    } // In checkoutFlow mode, accumulate scanned items and remain on this screen
    if (widget.checkoutFlow) {
      await _cameraController?.stopImageStream();
      try {
        final hp = Provider.of<HomepageProvider>(context, listen: false);

        // More flexible product search
        Product? foundProduct;
        // Try to find product with flexible matching
        for (var product in hp.homeAllProducts) {
          if (_isProductCodeMatch(product.kodeProduk, barcode)) {
            foundProduct = product;
            break;
          }
        }

        if (foundProduct != null) {
          setState(() {
            _checkoutScanned.add(foundProduct!);
            _scannedBarcode = null;
          });
          if (await Vibration.hasVibrator() == true)
            Vibration.vibrate(duration: 100);

          _showCustomSnackBar('Produk ditambahkan: ${foundProduct.namaProduk}',
              isError: false);
        } else {
          _showCustomSnackBar('Produk tidak ditemukan dengan barcode: $barcode',
              isError: true);
        }
      } catch (e) {
        print('Error finding product: $e');
        _showCustomSnackBar('Produk tidak terdaftar', isError: true);
        setState(() {
          _scannedBarcode = null;
        });
      }
      // Pause 1 second before next scan
      await Future.delayed(const Duration(seconds: 1));
      _cameraController?.startImageStream(_processCameraImage);
      _isDetecting = false;
      return;
    }

    ProductProvider? provider;
    try {
      provider = Provider.of<ProductProvider>(context, listen: false);
    } catch (_) {
      // fallback for non-manage mode
      Navigator.of(context).pop(barcode);
      return;
    }
    final now = DateTime.now();
    // If still within blocked period from previous duplicate, ignore
    if (_blockedUntil != null && now.isBefore(_blockedUntil!)) {
      return;
    } // Prevent duplicate scans with flexible matching
    bool isDuplicate = false;
    // Check pending products
    for (var pendingProduct in _pendingProducts) {
      if (_isProductCodeMatch(pendingProduct.code, barcode)) {
        isDuplicate = true;
        break;
      }
    }

    // Check existing products
    if (!isDuplicate) {
      for (var product in provider.allProducts) {
        if (_isProductCodeMatch(product.kodeProduk, barcode)) {
          isDuplicate = true;
          break;
        }
      }
    }

    if (isDuplicate) {
      // Show snack once and start block timer
      _showCustomSnackBar('Produk sudah terdaftar', isError: true);
      // Block new scans for 5 seconds
      _blockedUntil = now.add(const Duration(seconds: 5));
      setState(() => _scannedBarcode = null);
      await Future.delayed(const Duration(seconds: 1));
      _isDetecting = false;
      return;
    }

    final pending = PendingProduct(code: barcode);
    setState(() {
      _pendingProducts.add(pending);
      _scannedBarcode = null; // allow next scan when done
    });

    // Haptic feedback
    if (await Vibration.hasVibrator() == true) Vibration.vibrate(duration: 100);
    await _cameraController?.stopImageStream();

    // Fetch product data via provider
    try {
      final fetched = await provider.processBarcodeData(barcode);
      setState(() {
        pending.isLoading = false;
        pending.nameController.text = fetched?.name ?? '';
        if (fetched?.imageFile != null) {
          pending.imageUrl = fetched!.imageFile!.path;
        }
      });
    } catch (e) {
      setState(() => pending.isLoading = false);
      _showCustomSnackBar('Gagal memuat produk', isError: true);
    }

    _cameraController?.startImageStream(_processCameraImage);
  }

  void _toggleFlash() async {
    if (_cameraController?.value.isInitialized == true) {
      try {
        await _cameraController!.setFlashMode(
          _isFlashOn ? FlashMode.off : FlashMode.torch,
        );
        setState(() {
          _isFlashOn = !_isFlashOn;
        });
      } catch (e) {
        print('Error toggling flash: $e');
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        // Show error message in UI
      });
      _showCustomSnackBar(message, isError: true);
    }
  }

  // Helper function for flexible product code matching
  bool _isProductCodeMatch(String productCode, String barcode) {
    final cleanProductCode = productCode.trim().toUpperCase();
    final cleanBarcode = barcode.trim().toUpperCase();

    // 1. Exact match
    if (cleanProductCode == cleanBarcode) return true;

    // 2. Contains match (for codes with prefixes/suffixes)
    if (cleanProductCode.contains(cleanBarcode) ||
        cleanBarcode.contains(cleanProductCode)) return true;

    // 3. Remove common separators and try again
    final normalizedProductCode =
        cleanProductCode.replaceAll(RegExp(r'[-_\s]'), '');
    final normalizedBarcode = cleanBarcode.replaceAll(RegExp(r'[-_\s]'), '');
    if (normalizedProductCode == normalizedBarcode) return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Scan Barcode',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
              size: 28,
            ),
            onPressed: _toggleFlash,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview and overlays
          _buildBody(),
          // Pending items sheet (manage-product mode)
          if (!widget.checkoutFlow && _pendingProducts.isNotEmpty)
            DraggableScrollableSheet(
              initialChildSize: 0.2,
              minChildSize: 0.2,
              maxChildSize: 0.5,
              builder: (context, scrollCtrl) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.shopping_cart_outlined,
                                color: Colors.blue.shade600,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Keranjang (${_pendingProducts.length})',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollCtrl,
                          itemCount: _pendingProducts.length,
                          itemBuilder: (context, index) {
                            final item = _pendingProducts[index];
                            if (item.isLoading) {
                              // Skeleton placeholder row
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Container(
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Container(
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            // Loaded item with image and input fields
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                          color: Colors.grey.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: item.imageUrl != null
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: item.imageUrl!
                                                        .startsWith('http')
                                                    ? Image.network(
                                                        item.imageUrl!,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Image.file(
                                                        File(item.imageUrl!),
                                                        fit: BoxFit.cover,
                                                      ),
                                              )
                                            : Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey.shade400,
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextField(
                                          controller: item.nameController,
                                          decoration: InputDecoration(
                                            labelText: 'Nama Produk',
                                            labelStyle: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.grey.shade300),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.grey.shade300),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.blue.shade500),
                                            ),
                                          ),
                                          style:
                                              GoogleFonts.poppins(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: item.modalController,
                                          decoration: InputDecoration(
                                            labelText: 'Harga Modal',
                                            labelStyle: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.grey.shade300),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.grey.shade300),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.blue.shade500),
                                            ),
                                          ),
                                          keyboardType: TextInputType.number,
                                          style:
                                              GoogleFonts.poppins(fontSize: 13),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: item.jualController,
                                          decoration: InputDecoration(
                                            labelText: 'Harga Jual',
                                            labelStyle: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.grey.shade300),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.grey.shade300),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.blue.shade500),
                                            ),
                                          ),
                                          keyboardType: TextInputType.number,
                                          style:
                                              GoogleFonts.poppins(fontSize: 13),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: item.stokController,
                                          decoration: InputDecoration(
                                            labelText: 'Stok',
                                            labelStyle: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.grey.shade300),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.grey.shade300),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.blue.shade500),
                                            ),
                                          ),
                                          keyboardType: TextInputType.number,
                                          style:
                                              GoogleFonts.poppins(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: Colors.red.shade600,
                                          size: 16,
                                        ),
                                        label: Text(
                                          'Hapus',
                                          style: GoogleFonts.poppins(
                                            color: Colors.red.shade600,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        onPressed: () => setState(() =>
                                            _pendingProducts.removeAt(index)),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () async {
                                          final provider =
                                              Provider.of<ProductProvider>(
                                                  context,
                                                  listen: false);
                                          final newProd =
                                              await provider.addProduct(
                                            name:
                                                item.nameController.text.trim(),
                                            code: item.code,
                                            stock: int.parse(
                                                item.stokController.text),
                                            costPrice: double.parse(
                                                item.modalController.text),
                                            sellingPrice: double.parse(
                                                item.jualController.text),
                                            tempImageFile: item.imageUrl != null
                                                ? File(item.imageUrl!)
                                                : null,
                                          );
                                          if (newProd != null) {
                                            setState(() => _pendingProducts
                                                .removeAt(index));
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.shade600,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: Text(
                                          'Tambah',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          // CheckoutFlow sheet: collected products until Checkout
          if (widget.checkoutFlow && _checkoutScanned.isNotEmpty)
            DraggableScrollableSheet(
              initialChildSize: 0.25,
              minChildSize: 0.25,
              maxChildSize: 0.8,
              builder: (context, scrollCtrl) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 6)
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Produk (${_checkoutScanned.length})',
                              style: GoogleFonts.poppins(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                final distinctProducts = <int, Product>{};
                                final qtyMap = <int, int>{};
                                for (var p in _checkoutScanned) {
                                  distinctProducts[p.id!] = p;
                                  qtyMap[p.id!] = (qtyMap[p.id!] ?? 0) + 1;
                                }
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (ctx) => ChangeNotifierProvider<
                                        CheckoutProvider>(
                                      create: (_) => CheckoutProvider(
                                        userId: Provider.of<HomepageProvider>(
                                                context,
                                                listen: false)
                                            .userId,
                                        initialCartQuantities: qtyMap,
                                        initialCartProducts:
                                            distinctProducts.values.toList(),
                                      ),
                                      child: const CheckoutScreen(),
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Checkout'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollCtrl,
                          itemCount: _checkoutScanned.length,
                          itemBuilder: (c, index) {
                            final p = _checkoutScanned[index];
                            return ListTile(
                              title: Text(p.namaProduk),
                              subtitle: Text('Kode: ${p.kodeProduk}'),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_cameraController?.value.isInitialized != true) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      children: [
        // Camera Preview
        Positioned.fill(
          child: CameraPreview(_cameraController!),
        ),

        // Scan overlay
        _buildScanOverlay(),

        // Success indicator when barcode is found
        if (_scannedBarcode != null) _buildSuccessOverlay(),

        // Instructions
        _buildInstructions(),
      ],
    );
  }

  Widget _buildScanOverlay() {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(
            color: _scannedBarcode != null ? Colors.green : Colors.white,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Corner brackets
            ...List.generate(4, (index) {
              return Positioned(
                top: index < 2 ? 0 : null,
                bottom: index >= 2 ? 0 : null,
                left: index % 2 == 0 ? 0 : null,
                right: index % 2 == 1 ? 0 : null,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    border: Border(
                      top: index < 2
                          ? BorderSide(
                              color: _scannedBarcode != null
                                  ? Colors.green
                                  : Colors.white,
                              width: 4)
                          : BorderSide.none,
                      bottom: index >= 2
                          ? BorderSide(
                              color: _scannedBarcode != null
                                  ? Colors.green
                                  : Colors.white,
                              width: 4)
                          : BorderSide.none,
                      left: index % 2 == 0
                          ? BorderSide(
                              color: _scannedBarcode != null
                                  ? Colors.green
                                  : Colors.white,
                              width: 4)
                          : BorderSide.none,
                      right: index % 2 == 1
                          ? BorderSide(
                              color: _scannedBarcode != null
                                  ? Colors.green
                                  : Colors.white,
                              width: 4)
                          : BorderSide.none,
                    ),
                  ),
                ),
              );
            }),

            // Scanning line animation
            if (_scannedBarcode == null) _buildScanningLine(),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningLine() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Positioned(
            top: value * 230,
            left: 10,
            right: 10,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.red,
                    Colors.transparent,
                  ],
                ),
              ),
            ));
      },
      onEnd: () {
        if (_scannedBarcode == null && mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildSuccessOverlay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              'Barcode Terdeteksi!',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _scannedBarcode ?? '',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Positioned(
      bottom: 100,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_scanner,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Arahkan kamera ke barcode produk',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Pastikan barcode berada dalam kotak dan cahaya cukup',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Model for pending items
class PendingProduct {
  final String code;
  bool isLoading;
  String? name; // Added this field
  String? imageUrl;
  final TextEditingController modalController = TextEditingController();
  final TextEditingController jualController = TextEditingController();
  final TextEditingController stokController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  PendingProduct({required this.code, this.isLoading = true});
}
