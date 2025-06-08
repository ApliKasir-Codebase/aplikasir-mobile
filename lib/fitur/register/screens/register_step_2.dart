// lib/fitur/register/screens/register_step_2.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/register_provider.dart';
import 'package:aplikasir_mobile/fitur/login/screens/login_screen.dart';

class RegisterStep2Screen extends StatelessWidget {
  const RegisterStep2Screen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RegisterProvider>(context);

    return PopScope(
      canPop: !provider.isLoading,
      onPopInvoked: (didPop) {},
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8F8),
        appBar: AppBar(
          title: Text('Unggah Foto Profil',
              style: GoogleFonts.poppins(
                  color: Colors.blue[700], fontWeight: FontWeight.w600)),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.blue[700]),
          elevation: 1.0,
          centerTitle: true,
          shadowColor: Colors.black26,
          automaticallyImplyLeading: !provider.isLoading,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              _buildMainUIWidget(context, provider),
              if (provider.isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white)),
                        const SizedBox(height: 15),
                        Text('Mendaftarkan akun...',
                            style: GoogleFonts.poppins(
                                color: Colors.white, fontSize: 16))
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainUIWidget(BuildContext context, RegisterProvider provider) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(30.0),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Unggah Foto Profil Anda',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  const SizedBox(height: 15),
                  Text('Foto ini akan ditampilkan di profil Anda.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 35),
                  Center(
                    child: GestureDetector(
                      onTap: () =>
                          _showImageSourceActionSheetForUI(context, provider),
                      child: CircleAvatar(
                        radius: 80,
                        backgroundColor: Colors.grey.shade100,
                        backgroundImage: provider.profileImageTemporaryFile !=
                                    null &&
                                provider.profileImageTemporaryFile!.existsSync()
                            ? FileImage(provider.profileImageTemporaryFile!)
                            : null,
                        child: provider.profileImageTemporaryFile == null ||
                                !provider.profileImageTemporaryFile!
                                    .existsSync()
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    Icon(Icons.camera_alt_outlined,
                                        size: 50, color: Colors.grey.shade500),
                                    const SizedBox(height: 8),
                                    Text("Pilih Foto",
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey.shade600))
                                  ])
                            : Container(
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withOpacity(0.4)),
                                child: const Center(
                                    child: Icon(Icons.edit_rounded,
                                        size: 40, color: Colors.white))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 45),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final success = await provider.registerUser();
                      if (success) {
                        // Navigate to login, clearing navigation stack
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Registration failed')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        disabledBackgroundColor:
                            Colors.blue[200]?.withOpacity(0.7),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0)),
                        elevation: 3),
                    icon: const Icon(Icons.person_add_alt_1_rounded,
                        color: Colors.white),
                    label: Text('Selesaikan Pendaftaran',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceActionSheetForUI(
      BuildContext context, RegisterProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0))),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pilih dari Galeri'),
                onTap: () =>
                    _pickImageFromSource(ctx, ImageSource.gallery, provider),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Ambil Foto dengan Kamera'),
                onTap: () =>
                    _pickImageFromSource(ctx, ImageSource.camera, provider),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromSource(BuildContext context, ImageSource source,
      RegisterProvider provider) async {
    if (provider.isLoading) return;
    final file = await provider.pickProfileImage(source);
    if (file != null) {
      provider.setCroppedProfileImage(file);
    } else if (provider.errorMessage != null) {
      _showErrorSnackbar(context, provider.errorMessage!);
    }
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }
}
