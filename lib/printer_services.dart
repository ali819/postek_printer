import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

//  Fuungsi untuk print label ganda
bool printDoubleLabel({
  required String printerName,
  required String sku1,
  required String idPotong1,
  required String sku2,
  required String idPotong2,
  required int jumlah,
  required void Function(String message) onError,
}) {
  Pointer<IntPtr>? hPrinter;
  Pointer<Utf16>? printerNamePtr;
  Pointer<Utf8>? dataPtr;
  Pointer<DOC_INFO_1>? docInfo;

  try {
    hPrinter = calloc<IntPtr>();
    printerNamePtr = printerName.toNativeUtf16();
    final openSuccess = OpenPrinter(printerNamePtr, hPrinter, nullptr);

    if (openSuccess == 0) {
      onError('Gagal membuka printer "$printerName".');
      return false;
    }

    docInfo = calloc<DOC_INFO_1>()
      ..ref.pDocName = 'Double Label'.toNativeUtf16()
      ..ref.pOutputFile = nullptr
      ..ref.pDatatype = 'RAW'.toNativeUtf16();

    StartDocPrinter(hPrinter.value, 1, docInfo.cast());
    StartPagePrinter(hPrinter.value);

    final tspl = '''
    SIZE 100 mm,40 mm
    GAP 2 mm,0
    DENSITY 8
    DIRECTION 1
    CLS
    TEXT 30,30,"3",0,1,1,"$idPotong1"
    BARCODE 30,70,"128",80,1,0,2,2,"$sku1"
    TEXT 280,30,"3",0,1,1,"$idPotong2"
    BARCODE 280,70,"128",80,1,0,2,2,"$sku2"
    PRINT $jumlah
    ''';

    dataPtr = tspl.toNativeUtf8();
    final writeResult = WritePrinter(hPrinter.value, dataPtr.cast(), tspl.length, nullptr);

    if (writeResult == 0) {
      onError("Gagal mengirim data ke printer.");
      return false;
    }

    EndPagePrinter(hPrinter.value);
    EndDocPrinter(hPrinter.value);
    ClosePrinter(hPrinter.value);

    return true;
  } catch (e) {
    onError("Terjadi kesalahan: $e");
    return false;
  } finally {
    // Pastikan semua pointer dibebaskan
    if (dataPtr != null) calloc.free(dataPtr);
    if (docInfo != null) {
      calloc.free(docInfo.ref.pDocName);
      calloc.free(docInfo.ref.pDatatype);
      calloc.free(docInfo);
    }
    if (printerNamePtr != null) calloc.free(printerNamePtr);
    if (hPrinter != null) calloc.free(hPrinter);
  }
}


