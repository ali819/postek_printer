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
  final String sku1;
  final String idPotong1;
  final String sku2;
  final String idPotong2;
  final int jumlah;

  LabelPrintParams({
    required this.printerName,
    required this.sku1,
    required this.idPotong1,
    required this.sku2,
    required this.idPotong2,
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
      SIZE 100 mm,40 mm
      GAP 2 mm,0
      DENSITY 8
      DIRECTION 1
      CLS
      TEXT 30,30,"3",0,1,1,"${params.idPotong1}"
      BARCODE 30,70,"128",80,1,0,2,2,"${params.sku1}"
      TEXT 280,30,"3",0,1,1,"${params.idPotong2}"
      BARCODE 280,70,"128",80,1,0,2,2,"${params.sku2}"
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



