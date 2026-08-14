import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/currency_service.dart';
import '../services/receipt_ocr_service.dart';
import '../theme/app_theme.dart';

class OCRScannerScreen extends StatefulWidget {
  final Function(double amount, String title, String category) onParsedResult;

  const OCRScannerScreen({super.key, required this.onParsedResult});

  @override
  State<OCRScannerScreen> createState() => _OCRScannerScreenState();
}

class _OCRScannerScreenState extends State<OCRScannerScreen> {
  final ReceiptOCRService _ocrService = ReceiptOCRService();
  File? _selectedImage;
  bool _isProcessing = false;
  ReceiptParseResult? _parseResult;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(source: source, imageQuality: 85);
      if (photo == null) return;

      setState(() {
        _selectedImage = File(photo.path);
        _isProcessing = true;
        _parseResult = null;
      });

      final result = await _ocrService.processImage(_selectedImage!);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _parseResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process image: $e', style: GoogleFonts.plusJakartaSans()),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = CurrencyService.currencySymbolNotifier.value;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'AI Receipt OCR Scanner',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          children: [
            // Instructions Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.monexBlue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppTheme.monexBlue, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Snap or upload any paper receipt to automatically extract amount, merchant, and category.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Image Preview or Placeholder
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F3F9), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF101828).withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF667085), size: 28),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No Receipt Selected',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose camera or gallery below',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF98A2B3)),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 20),

            // Camera / Gallery Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: Text('Camera', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.monexBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: Text('Gallery', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: AppTheme.monexBlue,
                      side: const BorderSide(color: AppTheme.monexBlue, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Loading / Parsed Output Card
            if (_isProcessing)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F3F9)),
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: AppTheme.monexBlue),
                    const SizedBox(height: 14),
                    Text(
                      'Analyzing receipt with Optical OCR...',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              )
            else if (_parseResult != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF1F3F9), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF101828).withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Extracted Data', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'AI READY',
                            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF12B76A), fontWeight: FontWeight.w800, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildExtractedRow('Merchant / Title', _parseResult!.merchant ?? 'Receipt Merchant'),
                    const Divider(height: 20, color: Color(0xFFF1F3F9)),
                    _buildExtractedRow('Total Amount', '$currencySymbol${(_parseResult!.amount ?? 0.0).toStringAsFixed(2)}'),
                    const Divider(height: 20, color: Color(0xFFF1F3F9)),
                    _buildExtractedRow('Category', _parseResult!.category),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onParsedResult(
                            _parseResult!.amount ?? 0.0,
                            _parseResult!.merchant ?? 'Receipt Merchant',
                            _parseResult!.category,
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.monexBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('IMPORT TO EXPENSES', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtractedRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF667085), fontWeight: FontWeight.w500)),
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      ],
    );
  }
}
