import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

/// A reusable image picker widget with modern design
/// Provides image selection, display, edit, and remove functionality
class CommonImagePicker extends StatefulWidget {
  final String? initialImagePath;
  final Function(File?)? onImageChanged;
  final String? labelText;
  final String? hintText;
  final double? width;
  final double? height;
  final bool showButtons;
  final VoidCallback? onEditPressed;
  final VoidCallback? onRemovePressed;

  const CommonImagePicker({
    super.key,
    this.initialImagePath,
    this.onImageChanged,
    this.labelText = 'Tambah Gambar',
    this.hintText = 'Ketuk untuk memilih',
    this.width = 160,
    this.height = 160,
    this.showButtons = true,
    this.onEditPressed,
    this.onRemovePressed,
  });

  @override
  State<CommonImagePicker> createState() => _CommonImagePickerState();
}

class _CommonImagePickerState extends State<CommonImagePicker> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null) {
      _selectedImage = File(widget.initialImagePath!);
    }
  }

  ImageProvider? get _currentImageProvider {
    if (_selectedImage != null && _selectedImage!.existsSync()) {
      return FileImage(_selectedImage!);
    }
    return null;
  }

  Future<void> _showImageSourceActionSheet(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      'Pilih Sumber Gambar',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSourceOption(
                          icon: Icons.photo_camera,
                          label: 'Kamera',
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.camera);
                          },
                        ),
                        _buildSourceOption(
                          icon: Icons.photo_library,
                          label: 'Galeri',
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.gallery);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: Colors.blue.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        widget.onImageChanged?.call(_selectedImage);
      }
    } catch (e) {
      // Handle error silently or show a snackbar
      debugPrint('Error picking image: $e');
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
    widget.onImageChanged?.call(null);
    widget.onRemovePressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final currentImageProvider = _currentImageProvider;

    return Column(
      children: [
        // Image container with modern design
        Container(
          width: widget.width,
          height: widget.height,
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
                  ),
                  image: currentImageProvider != null
                      ? DecorationImage(
                          image: currentImageProvider,
                          fit: BoxFit.cover,
                        )
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
                            widget.labelText!,
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.hintText!,
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
        if (widget.showButtons)
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
                  onPressed: widget.onEditPressed ??
                      () => _showImageSourceActionSheet(context),
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
                  onPressed: _removeImage,
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
      ],
    );
  }
}
