import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
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
  final String tanggal;
  final int jumlah;

  LabelPrintParams({
    required this.printerName,
    required this.skuKiri,
    required this.idPotongKiri,
    required this.skuKanan,
    required this.idPotongKanan,
    required this.tanggal,
    required this.jumlah,
  });
}

//  Fuungsi untuk print label ganda
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

      final tspl = '''
      SIZE 100 mm,20 mm
      GAP 2 mm,0
      DENSITY 8
      DIRECTION 1
      CLS

      TEXT 5,5,"3",0,1,1,"YOUNIQ EXCLUSIVE"
      BARCODE 5,25,"128",40,1,0,2,2,"${params.skuKiri}"
      TEXT 5,70,"3",0,1,1,"${params.skuKiri}"
      TEXT 5,90,"3",0,1,1,"${params.tanggal}/${params.idPotongKiri}"

      TEXT 55,5,"3",0,1,1,"YOUNIQ EXCLUSIVE"
      BARCODE 55,25,"128",40,1,0,2,2,"${params.skuKanan}"
      TEXT 55,70,"3",0,1,1,"${params.skuKanan}"
      TEXT 55,90,"3",0,1,1,"${params.tanggal}/${params.idPotongKanan}"

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


