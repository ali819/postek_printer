import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:intl/intl.dart';
import 'package:win32/win32.dart';

class PrintResult {
  final bool success;
  final String? error;

  PrintResult({required this.success, this.error});
}

class LabelPrintParams {
  final String printerName;
  final String skuKiri;
  final String idPotongKiri;
  final String skuKanan;
  final String idPotongKanan;
  final int jumlah;

  LabelPrintParams({
    required this.printerName,
    required this.skuKiri,
    required this.idPotongKiri,
    required this.skuKanan,
    required this.idPotongKanan,
    required this.jumlah,
  });
}

// Fungsi untuk menghitung posisi X agar teks rata tengah dalam area
int centerTextX({
  required String text,
  required int areaWidth,
  int charWidth = 8,
  int scaleX = 1,
}) {
  final totalTextWidth = text.length * charWidth * scaleX;
  return ((areaWidth - totalTextWidth) / 2).round();
}

// Fungsi untuk menghitung posisi X agar teks rata kanan dalam area
int rightAlignTextX({
  required String text,
  required int areaWidth,
  int charWidth = 8,
  int scaleX = 1,
  int paddingRight = 10,
}) {
  final totalTextWidth = text.length * charWidth * scaleX;
  return areaWidth - totalTextWidth - paddingRight;
}

// Fungsi untuk menghitung lebar barcode berdasarkan panjang data
// Kode 128 membutuhkan sekitar 11 modul (unit) per karakter + 2 untuk start/stop.
// Misalnya, untuk 10 karakter, lebar barcode = (10 * 11 + 2) * narrow
int barcodeWidth({
  required String data,
  int narrow = 2,
}) {
  final charCount = data.length;
  final moduleCount = (charCount * 11 + 2); // asumsi kasar untuk Code 128
  return moduleCount * narrow;
}

// Fungsi untuk print label (TSLP)
Future<PrintResult> computePrintDoubleLabel(LabelPrintParams params) async {
  return await Isolate.run(() {
    Pointer<IntPtr>? hPrinter;
    Pointer<Utf16>? printerNamePtr;
    Pointer<Utf8>? dataPtr;
    Pointer<DOC_INFO_1>? docInfo;
    Pointer<Utf16>? docNamePtr;
    Pointer<Utf16>? dataTypePtr;

    try {
      hPrinter = calloc<IntPtr>();
      printerNamePtr = params.printerName.toNativeUtf16();

      final openSuccess = OpenPrinter(printerNamePtr, hPrinter, nullptr);
      if (openSuccess == 0) {
        return PrintResult(success: false, error: 'Gagal membuka printer "${params.printerName}".');
      }

      docNamePtr = 'Double Label'.toNativeUtf16();
      dataTypePtr = 'RAW'.toNativeUtf16();

      docInfo = calloc<DOC_INFO_1>()
        ..ref.pDocName = docNamePtr
        ..ref.pOutputFile = nullptr
        ..ref.pDatatype = dataTypePtr;

      if (StartDocPrinter(hPrinter.value, 1, docInfo.cast()) == 0) {
        return PrintResult(success: false, error: 'Gagal memulai dokumen.');
      }

      if (StartPagePrinter(hPrinter.value) == 0) {
        return PrintResult(success: false, error: 'Gagal memulai halaman printer.');
      }

      // Format tanggal ke ddMMyy
      final now = DateTime.now();
      final formattedTanggal = DateFormat('ddMMyy').format(now);

      // Area lebar (dalam dot) untuk masing-masing kolom (50 mm ~ 400 dots)
      final areaWidth = 400;

      // Text header
      const headerText = "YOUNIQ EXCLUSIVE";
      final headerXKiri = centerTextX(text: headerText, areaWidth: areaWidth);
      final headerXKanan = centerTextX(text: headerText, areaWidth: areaWidth) + 400;

      // SKU teks
      final skuTextKiriX = centerTextX(text: params.skuKiri, areaWidth: areaWidth);
      final skuTextKananX = centerTextX(text: params.skuKanan, areaWidth: areaWidth) + 400;

      // Barcode X posisi (Kode 128)
      final barcodeWidthKiri = barcodeWidth(data: params.skuKiri);
      final barcodeXKiri = ((areaWidth - barcodeWidthKiri) / 2).clamp(0, areaWidth - barcodeWidthKiri).round();
      final barcodeWidthKanan = barcodeWidth(data: params.skuKanan);
      final barcodeXKanan = ((areaWidth - barcodeWidthKanan) / 2).clamp(0, areaWidth - barcodeWidthKanan).round() + 400;

      // Tanggal/ID Potong teks (rata kanan)
      final bottomTextKiriX = rightAlignTextX(text: "$formattedTanggal/${params.idPotongKiri}", areaWidth: areaWidth);
      final bottomTextKananX = rightAlignTextX(text: "$formattedTanggal/${params.idPotongKanan}",areaWidth: areaWidth) + 400;

      final tspl = '''
      SIZE 100 mm,20 mm
      GAP 2 mm,0
      DENSITY 8
      DIRECTION 1
      CLS

      TEXT $headerXKiri,5,"3",0,1,1,"$headerText"
      BARCODE $barcodeXKiri,25,"128",40,1,0,2,2,"${params.skuKiri}"
      TEXT $skuTextKiriX,70,"3",0,1,1,"${params.skuKiri}"
      TEXT $bottomTextKiriX,90,"2",0,1,1,"$formattedTanggal/${params.idPotongKiri}"

      TEXT $headerXKanan,5,"3",0,1,1,"$headerText"
      BARCODE $barcodeXKanan,25,"128",40,1,0,2,2,"${params.skuKanan}"
      TEXT $skuTextKananX,70,"3",0,1,1,"${params.skuKanan}"
      TEXT $bottomTextKananX,90,"2",0,1,1,"$formattedTanggal/${params.idPotongKanan}"

      PRINT ${params.jumlah}
      ''';

      dataPtr = tspl.toNativeUtf8();
      final written = calloc<Uint32>();
      final writeSuccess = WritePrinter(hPrinter.value, dataPtr.cast(), tspl.length, written);

      if (writeSuccess == 0 || written.value == 0) {
        return PrintResult(success: false, error: 'Gagal mengirim data ke printer.');
      }

      EndPagePrinter(hPrinter.value);
      EndDocPrinter(hPrinter.value);
      ClosePrinter(hPrinter.value);

      return PrintResult(success: true);
    } catch (e) {
      return PrintResult(success: false, error: "Terjadi kesalahan: $e");
    } finally {
      if (dataPtr != null) calloc.free(dataPtr);
      if (docNamePtr != null) calloc.free(docNamePtr);
      if (dataTypePtr != null) calloc.free(dataTypePtr);
      if (docInfo != null) calloc.free(docInfo);
      if (printerNamePtr != null) calloc.free(printerNamePtr);
      if (hPrinter != null) calloc.free(hPrinter);
    }
  });
}

// Fungsi untuk cetak label (IMAGE)
Future<PrintResult> computePrintDoubleLabelAsImage(LabelPrintParams params) async {
  // TODO: Implement the function logic here.
  return PrintResult(success: false, error: 'Function not implemented.');
}

// Fungsi untuk cetak label (Bitmap)
Future<PrintResult> computePrintDoubleLabelAsBitmap(LabelPrintParams params) async {
  // TODO: Implement the function logic here.
  return PrintResult(success: false, error: 'Function not implemented.');
}

// Fungsi untuk membatalkan semua pekerjaan cetak pada printer tertentu
// ignore: constant_identifier_names
const int JOB_CONTROL_CANCEL = 0x00000001;
Future<void> cancelAllPrintJobs(String printerName) async {
  return Future(() {
    final printerHandlePtr = calloc<HANDLE>();

    final opened = OpenPrinter(printerName.toNativeUtf16(), printerHandlePtr, nullptr);
    if (opened == 0) {
      calloc.free(printerHandlePtr);
      throw Exception('Gagal membuka printer: $printerName');
    }

    final handle = printerHandlePtr.value;
    final jobCount = calloc<Uint32>();
    final bytesNeeded = calloc<Uint32>();

    // Panggilan pertama untuk ambil ukuran buffer
    EnumJobs(handle, 0, 999, 1, nullptr, 0, bytesNeeded, jobCount);

    final needed = bytesNeeded.value;
    if (needed == 0) {
      ClosePrinter(handle);
      calloc.free(printerHandlePtr);
      calloc.free(jobCount);
      calloc.free(bytesNeeded);
      return;
    }

    final buffer = calloc<Uint8>(needed);
    final success = EnumJobs(handle, 0, 999, 1, buffer, needed, bytesNeeded, jobCount);
    if (success == 0) {
      ClosePrinter(handle);
      calloc.free(buffer);
      calloc.free(printerHandlePtr);
      throw Exception("Gagal membaca job printer");
    }

    final jobStructSize = sizeOf<JOB_INFO_1>();
    final jobCountVal = jobCount.value;

    for (var i = 0; i < jobCountVal; i++) {
      final job = Pointer<JOB_INFO_1>.fromAddress(buffer.address + i * jobStructSize).ref;
      SetJob(handle, job.JobId, 0, nullptr, JOB_CONTROL_CANCEL);
    }

    calloc.free(buffer);
    ClosePrinter(handle);
    calloc.free(printerHandlePtr);
    calloc.free(jobCount);
    calloc.free(bytesNeeded);
  });
}


