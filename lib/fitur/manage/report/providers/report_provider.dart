// lib/fitur/manage/report/providers/report_provider.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Impor chart
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';

enum ReportSegment { day, week, month, all }

class ReportProvider extends ChangeNotifier {
  final int userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  ReportSegment _selectedSegment = ReportSegment.day;
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _selectedWeek;
  DateTime? _selectedMonth;

  List<TransactionModel> _allTransactionsForPeriod =
      []; // Transaksi dari DB sesuai periode
  List<TransactionModel> _salesTransactionsForStats =
      []; // Hanya transaksi penjualan untuk statistik

  bool _isLoading = true;
  String _errorMessage = '';

  // Statistik
  int _totalSalesCount = 0;
  double _totalRevenue = 0.0;
  double _totalProfit = 0.0;

  // Data Chart
  List<FlSpot> _salesChartData = [];
  double _chartMaxY = 0; // Untuk skala chart
  Map<int, String> _chartBottomTitles = {}; // Label sumbu X

  // Getters
  ReportSegment get selectedSegment => _selectedSegment;
  DateTime get selectedDate => _selectedDate;
  DateTimeRange? get selectedWeek => _selectedWeek;
  DateTime? get selectedMonth => _selectedMonth;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<TransactionModel> get salesTransactionsForDisplay =>
      _salesTransactionsForStats; // Untuk daftar transaksi di UI

  int get totalSalesCount => _totalSalesCount;
  double get totalRevenue => _totalRevenue;
  double get totalProfit => _totalProfit;
  List<FlSpot> get salesChartData => _salesChartData;
  double get chartMaxY => _chartMaxY;
  Map<int, String> get chartBottomTitles => _chartBottomTitles;

  ReportProvider({required this.userId}) {
    final now = DateTime.now();
    _selectedWeek = DateTimeRange(
        start: now.subtract(Duration(days: now.weekday - 1)), // Senin
        end: now
            .add(Duration(days: DateTime.daysPerWeek - now.weekday))); // Minggu
    _selectedMonth = DateTime(now.year, now.month);
    loadAndProcessReports();
  }

  Future<void> loadAndProcessReports() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      DateTimeRange filterRange = _calculateDateRange();
      _allTransactionsForPeriod = await _dbHelper.getTransactionsByUserId(
        userId,
        startDate: filterRange.start,
        endDate: filterRange.end,
      );

      // Filter hanya transaksi penjualan untuk statistik dan daftar di UI
      _salesTransactionsForStats = _allTransactionsForPeriod
          .where((t) =>
                  t.metodePembayaran == 'Tunai' ||
                  t.metodePembayaran == 'QRIS' ||
                  t.metodePembayaran ==
                      'Kredit' // Penjualan kredit dihitung sebagai pendapatan
              )
          .toList();
      // Urutkan berdasarkan tanggal terbaru untuk tampilan daftar
      _salesTransactionsForStats
          .sort((a, b) => b.tanggalTransaksi.compareTo(a.tanggalTransaksi));

      _calculateStatistics();
      _prepareChartData();
    } catch (e) {
      _errorMessage = 'Gagal memuat laporan: ${e.toString()}';
      _resetReportData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _resetReportData() {
    _salesTransactionsForStats = [];
    _totalSalesCount = 0;
    _totalRevenue = 0.0;
    _totalProfit = 0.0;
    _salesChartData = [];
    _chartMaxY = 0;
    _chartBottomTitles = {};
  }

  DateTimeRange _calculateDateRange() {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    try {
      switch (_selectedSegment) {
        case ReportSegment.day:
          start = DateTime(_selectedDate.year, _selectedDate.month,
              _selectedDate.day, 0, 0, 0);
          end = DateTime(_selectedDate.year, _selectedDate.month,
              _selectedDate.day, 23, 59, 59, 999);
          break;
        case ReportSegment.week:
          if (_selectedWeek != null) {
            start = DateTime(_selectedWeek!.start.year,
                _selectedWeek!.start.month, _selectedWeek!.start.day, 0, 0, 0);
            end = DateTime(_selectedWeek!.end.year, _selectedWeek!.end.month,
                _selectedWeek!.end.day, 23, 59, 59, 999);
          } else {
            // Fallback to current week if _selectedWeek is null
            start = DateTime(
                now.year, now.month, now.day - now.weekday + 1, 0, 0, 0);
            end = DateTime(now.year, now.month, now.day - now.weekday + 7, 23,
                59, 59, 999);
          }
          break;
        case ReportSegment.month:
          if (_selectedMonth != null) {
            start = DateTime(
                _selectedMonth!.year, _selectedMonth!.month, 1, 0, 0, 0);
            end = DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 0,
                23, 59, 59, 999); // Hari ke-0 bulan berikutnya
          } else {
            // Fallback to current month if _selectedMonth is null
            start = DateTime(now.year, now.month, 1, 0, 0, 0);
            end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
          }
          break;
        case ReportSegment.all:
          // Ambil dari transaksi paling awal hingga sekarang
          // Ini bisa jadi query berat jika data banyak. Pertimbangkan batasan (misal 1 tahun)
          // Untuk contoh ini, kita batasi 5 tahun
          start = now.subtract(const Duration(days: 365 * 5));
          end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          break;
      }
    } catch (e) {
      print("Error calculating date range: $e");
      // Fallback to today if there's any error
      start = DateTime(now.year, now.month, now.day, 0, 0, 0);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    }

    return DateTimeRange(start: start, end: end);
  }

  void _calculateStatistics() {
    _totalSalesCount = _salesTransactionsForStats.length;
    _totalRevenue =
        _salesTransactionsForStats.fold(0.0, (sum, t) => sum + t.totalBelanja);

    double totalModalCost = 0;
    for (var transaction in _salesTransactionsForStats) {
      // Gunakan field totalModal dari TransactionModel
      // Ini lebih akurat jika sudah dihitung saat transaksi dibuat
      totalModalCost += transaction.totalModal;
    }
    _totalProfit = _totalRevenue - totalModalCost;
  }

  void _prepareChartData() {
    List<FlSpot> spots = [];
    Map<int, String> bottomTitles = {};
    double maxY = 0;
    final DateFormat monthYearFormat = DateFormat('MMM yy', 'id_ID');
    final DateFormat hourFormat = DateFormat('HH');

    if (_salesTransactionsForStats.isEmpty) {
      _salesChartData = [];
      _chartBottomTitles = {};
      _chartMaxY = 10000; // Default jika tidak ada data
      return;
    }

    Map<double, double> aggregatedSales = {};

    try {
      switch (_selectedSegment) {
        case ReportSegment.day:
          // Agregasi per jam
          for (var tx in _salesTransactionsForStats) {
            double hour = tx.tanggalTransaksi.hour.toDouble();
            aggregatedSales[hour] =
                (aggregatedSales[hour] ?? 0) + tx.totalBelanja;
          }
          for (int i = 0; i < 24; i++) {
            // Sumbu X dari 0 (00:00) hingga 23 (23:00)
            double sales = aggregatedSales[i.toDouble()] ?? 0;
            spots.add(FlSpot(i.toDouble(), sales));
            if (sales > maxY) maxY = sales;
            if (i % 4 == 0) {
              // Tampilkan label jam tiap 4 jam
              bottomTitles[i] = hourFormat.format(DateTime(0, 0, 0, i));
            }
          }
          break;
        case ReportSegment.week:
          // Agregasi per hari dalam seminggu
          for (var tx in _salesTransactionsForStats) {
            double dayOfWeek =
                tx.tanggalTransaksi.weekday.toDouble(); // 1 (Mon) - 7 (Sun)
            aggregatedSales[dayOfWeek] =
                (aggregatedSales[dayOfWeek] ?? 0) + tx.totalBelanja;
          }
          List<String> weekDayLabels = [
            'Sen',
            'Sel',
            'Rab',
            'Kam',
            'Jum',
            'Sab',
            'Min'
          ];
          for (int i = 1; i <= 7; i++) {
            double sales = aggregatedSales[i.toDouble()] ?? 0;
            spots.add(FlSpot(i.toDouble(), sales));
            if (sales > maxY) maxY = sales;
            bottomTitles[i] = weekDayLabels[i - 1];
          }
          break;
        case ReportSegment.month:
          // Agregasi per tanggal dalam sebulan
          if (_selectedMonth != null) {
            int daysInMonth =
                DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 0)
                    .day;
            for (var tx in _salesTransactionsForStats) {
              double dayOfMonth = tx.tanggalTransaksi.day.toDouble();
              aggregatedSales[dayOfMonth] =
                  (aggregatedSales[dayOfMonth] ?? 0) + tx.totalBelanja;
            }
            for (int i = 1; i <= daysInMonth; i++) {
              double sales = aggregatedSales[i.toDouble()] ?? 0;
              spots.add(FlSpot(i.toDouble(), sales));
              if (sales > maxY) maxY = sales;
              if (i == 1 || i % 5 == 0 || i == daysInMonth) {
                // Tampilkan label untuk tanggal tertentu
                bottomTitles[i] = i.toString();
              }
            }
          }
          break;
        case ReportSegment.all:
          // Agregasi per bulan dalam setahun (misal 12 bulan terakhir)
          DateTime endDate = DateTime.now();
          DateTime startDate = DateTime(endDate.year - 1, endDate.month + 1,
              1); // 12 bulan lalu dari awal bulan depan
          Map<String, double> monthlySales =
              {}; // Key: 'YYYY-MM', Value: total sales

          for (var tx in _salesTransactionsForStats) {
            if (tx.tanggalTransaksi
                    .isAfter(startDate.subtract(const Duration(days: 1))) &&
                tx.tanggalTransaksi
                    .isBefore(endDate.add(const Duration(days: 1)))) {
              String monthKey =
                  DateFormat('yyyy-MM').format(tx.tanggalTransaksi);
              monthlySales[monthKey] =
                  (monthlySales[monthKey] ?? 0) + tx.totalBelanja;
            }
          }

          List<String> sortedMonthKeys = monthlySales.keys.toList()..sort();
          if (sortedMonthKeys.length > 12) {
            // Batasi hingga 12 bulan terakhir jika datanya banyak
            sortedMonthKeys =
                sortedMonthKeys.sublist(sortedMonthKeys.length - 12);
          }

          for (int i = 0; i < sortedMonthKeys.length; i++) {
            String monthKey = sortedMonthKeys[i];
            double sales = monthlySales[monthKey] ?? 0;
            spots.add(
                FlSpot(i.toDouble(), sales)); // Sumbu X dari 0 hingga N-1 bulan
            if (sales > maxY) maxY = sales;
            // Label untuk sumbu X: Nama bulan
            try {
              DateTime dateFromKey = DateFormat('yyyy-MM').parse(monthKey);
              bottomTitles[i] = monthYearFormat.format(dateFromKey);
            } catch (e) {
              print("Error parsing month key: $monthKey, error: $e");
            }
          }
          break;
      }
    } catch (e) {
      print("Error preparing chart data: $e");
      // Set default values on error
      spots = [FlSpot(0, 0)];
      bottomTitles = {0: 'Error'};
      maxY = 10000;
    }

    _salesChartData = spots;
    _chartBottomTitles = bottomTitles;
    _chartMaxY = maxY == 0 ? 10000 : (maxY * 1.2); // Beri sedikit padding atas
  }

  // --- Update State Filter ---
  void setSelectedSegment(ReportSegment segment) {
    if (_selectedSegment != segment) {
      _selectedSegment = segment;
      loadAndProcessReports(); // Muat ulang data
    }
  }

  Future<void> setSelectedDate(BuildContext context) async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        locale: const Locale('id', 'ID'),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Colors.blue.shade700,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null && picked != _selectedDate) {
        _selectedDate = picked;
        loadAndProcessReports();
      }
    } catch (e) {
      print("Error selecting date: $e");
    }
  }

  Future<void> setSelectedWeek(BuildContext context) async {
    try {
      final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        initialDateRange: _selectedWeek,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 7)),
        locale: const Locale('id', 'ID'),
        helpText: 'Pilih Rentang Minggu',
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Colors.blue.shade700,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null && picked != _selectedWeek) {
        // Validasi agar range tidak lebih dari 7 hari jika ingin strictly per minggu
        if (picked.duration.inDays > 7) {
          // Ambil 7 hari dari tanggal mulai
          _selectedWeek = DateTimeRange(
              start: picked.start,
              end: picked.start.add(const Duration(days: 6)));
        } else {
          _selectedWeek = picked;
        }
        loadAndProcessReports();
      }
    } catch (e) {
      print("Error selecting week: $e");
    }
  }

  Future<void> setSelectedMonth(BuildContext context) async {
    try {
      final DateTime initial = _selectedMonth ?? DateTime.now();
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime(initial.year, initial.month),
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialEntryMode: DatePickerEntryMode.calendarOnly,
        initialDatePickerMode: DatePickerMode.year, // Start from year selection
        locale: const Locale('id', 'ID'),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Colors.blue.shade700,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );

      if (picked != null) {
        final pickedMonth = DateTime(picked.year, picked.month);
        if (pickedMonth != _selectedMonth) {
          _selectedMonth = pickedMonth;
          loadAndProcessReports();
        }
      }
    } catch (e) {
      print("Error selecting month: $e");
    }
  }

  // PDF Generation Methods
  Future<void> generateAndSharePDF(BuildContext context) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Membuat PDF...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Request storage permissions
      bool hasPermission = await _requestStoragePermissions();
      if (!hasPermission) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin penyimpanan diperlukan untuk menyimpan PDF'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final pdf = await _generatePDF();
      final bytes = await pdf.save();

      // Create ApliKasir folder in external storage
      final file = await _saveToExternalStorage(bytes);

      if (context.mounted) {
        // Show success message with options
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PDF berhasil dibuat!'),
                const SizedBox(height: 4),
                Text(
                  'Tersimpan di: ${file.path}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'BUKA',
              textColor: Colors.white,
              onPressed: () => _openFile(file),
            ),
          ),
        );

        // Also show a dialog with more options
        _showPDFSuccessDialog(context, file);
      }
    } catch (e) {
      print('Error generating PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<bool> _requestStoragePermissions() async {
    try {
      // For Android 11+ (API 30+), we need to request special permission
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }

      // Request storage permission
      var status = await Permission.storage.request();
      if (status.isGranted) {
        return true;
      }

      // For Android 11+, request manage external storage if regular storage permission is denied
      if (await Permission.manageExternalStorage.request().isGranted) {
        return true;
      }

      return false;
    } catch (e) {
      print('Error requesting storage permissions: $e');
      return false;
    }
  }

  Future<File> _saveToExternalStorage(List<int> bytes) async {
    try {
      // Try to get external storage directory (app-specific)
      Directory? externalDir;

      try {
        // Primary: Try to get external storage directory
        externalDir = await getExternalStorageDirectory();
      } catch (e) {
        print('Error getting external storage directory: $e');
      }

      // Fallback: Try to get application documents directory
      if (externalDir == null) {
        try {
          externalDir = await getApplicationDocumentsDirectory();
        } catch (e) {
          print('Error getting application documents directory: $e');
        }
      }

      // Final fallback: Try to get temporary directory
      if (externalDir == null) {
        try {
          externalDir = await getTemporaryDirectory();
        } catch (e) {
          print('Error getting temporary directory: $e');
          throw Exception('Cannot access any storage directory');
        }
      }

      // Create ApliKasir folder in the chosen directory
      final aplikasirDir = Directory('${externalDir.path}/ApliKasir');
      if (!await aplikasirDir.exists()) {
        await aplikasirDir.create(recursive: true);
      }

      // Create PDF file
      final fileName = _getPDFFilename();
      final file = File('${aplikasirDir.path}/$fileName');

      // Write PDF to file
      await file.writeAsBytes(bytes);

      print('PDF saved to: ${file.path}');
      return file;
    } catch (e) {
      print('Error saving to storage: $e');
      // Final fallback to app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final fileName = _getPDFFilename();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file;
    }
  }

  Future<void> _shareFile(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Laporan Penjualan ApliKasir',
        subject: 'Laporan Penjualan - ${_getPeriodText()}',
      );
    } catch (e) {
      print('Error sharing PDF: $e');
      // Fallback: just show the file path
      print('PDF saved at: ${file.path}');
    }
  }

  Future<void> _openFile(File file) async {
    try {
      // Check if file exists
      if (!await file.exists()) {
        print('File does not exist: ${file.path}');
        return;
      }

      final result = await OpenFile.open(file.path);
      print('OpenFile result: ${result.type} - ${result.message}');

      if (result.type != ResultType.done) {
        print('Error opening PDF: ${result.message}');
        // If opening fails, try alternative method
        await _openFileAlternative(file);
      }
    } catch (e) {
      print('Error opening PDF: $e');
      await _openFileAlternative(file);
    }
  }

  Future<void> _openFileAlternative(File file) async {
    try {
      // Alternative: Share the file which will show apps that can open it
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Buka PDF dengan aplikasi pilihan Anda',
        subject: 'Laporan PDF ApliKasir',
      );
    } catch (e) {
      print('Alternative open method also failed: $e');
    }
  }

  void _showPDFSuccessDialog(BuildContext context, File file) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('PDF Berhasil Dibuat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Laporan PDF telah berhasil dibuat.'),
              const SizedBox(height: 8),
              Text(
                'Lokasi: ${file.path}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openFile(file);
              },
              child: const Text('Buka'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _shareFile(file);
              },
              child: const Text('Bagikan'),
            ),
          ],
        );
      },
    );
  }

  Future<pw.Document> _generatePDF() async {
    final pdf = pw.Document();
    final DateFormat dateFormatter = DateFormat('dd MMMM yyyy', 'id_ID');
    final NumberFormat currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    String periodText = _getPeriodText();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Column(
                children: [
                  pw.Text(
                    'LAPORAN PENJUALAN',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    periodText,
                    style: pw.TextStyle(fontSize: 14),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Dibuat pada: ${dateFormatter.format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 30),

            // Statistics Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RINGKASAN STATISTIK',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 15),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: _buildStatItem(
                            'Total Penjualan', '$_totalSalesCount transaksi'),
                      ),
                      pw.Expanded(
                        child: _buildStatItem('Total Pendapatan',
                            currencyFormatter.format(_totalRevenue)),
                      ),
                      pw.Expanded(
                        child: _buildStatItem('Total Keuntungan',
                            currencyFormatter.format(_totalProfit)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 30),

            // Transaction List
            pw.Text(
              'DAFTAR TRANSAKSI',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 15),

            if (_salesTransactionsForStats.isEmpty)
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(20),
                child: pw.Text(
                  'Tidak ada transaksi pada periode ini',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('Tanggal & Waktu', isHeader: true),
                      _buildTableCell('Metode', isHeader: true),
                      _buildTableCell('Total', isHeader: true),
                      _buildTableCell('Keuntungan', isHeader: true),
                    ],
                  ),
                  // Data rows
                  ..._salesTransactionsForStats.take(50).map((transaction) {
                    final profit =
                        transaction.totalBelanja - transaction.totalModal;
                    return pw.TableRow(
                      children: [
                        _buildTableCell(DateFormat('dd/MM/yyyy HH:mm')
                            .format(transaction.tanggalTransaksi)),
                        _buildTableCell(transaction.metodePembayaran),
                        _buildTableCell(
                            currencyFormatter.format(transaction.totalBelanja)),
                        _buildTableCell(currencyFormatter.format(profit)),
                      ],
                    );
                  }).toList(),
                ],
              ),

            if (_salesTransactionsForStats.length > 50)
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 10),
                child: pw.Text(
                  'Menampilkan 50 transaksi pertama dari ${_salesTransactionsForStats.length} total transaksi',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ),
          ];
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildStatItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 12,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String _getPeriodText() {
    final DateFormat dateFormatter = DateFormat('dd MMMM yyyy', 'id_ID');
    final DateFormat monthFormatter = DateFormat('MMMM yyyy', 'id_ID');

    switch (_selectedSegment) {
      case ReportSegment.day:
        return 'Periode: ${dateFormatter.format(_selectedDate)}';
      case ReportSegment.week:
        if (_selectedWeek != null) {
          return 'Periode: ${dateFormatter.format(_selectedWeek!.start)} - ${dateFormatter.format(_selectedWeek!.end)}';
        }
        return 'Periode: Mingguan';
      case ReportSegment.month:
        if (_selectedMonth != null) {
          return 'Periode: ${monthFormatter.format(_selectedMonth!)}';
        }
        return 'Periode: Bulanan';
      case ReportSegment.all:
        return 'Periode: Semua Waktu';
    }
  }

  String _getPDFFilename() {
    final DateFormat fileFormatter = DateFormat('yyyy-MM-dd');
    String period = '';

    switch (_selectedSegment) {
      case ReportSegment.day:
        period = fileFormatter.format(_selectedDate);
        break;
      case ReportSegment.week:
        if (_selectedWeek != null) {
          period =
              '${fileFormatter.format(_selectedWeek!.start)}_to_${fileFormatter.format(_selectedWeek!.end)}';
        } else {
          period = 'mingguan';
        }
        break;
      case ReportSegment.month:
        if (_selectedMonth != null) {
          period = DateFormat('yyyy-MM').format(_selectedMonth!);
        } else {
          period = 'bulanan';
        }
        break;
      case ReportSegment.all:
        period = 'semua_waktu';
        break;
    }

    return 'laporan_penjualan_$period.pdf';
  }
}
