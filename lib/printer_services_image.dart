import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';
// import 'dart:ui' as ui;

// import 'package:barcode_widget/barcode_widget.dart';
import 'package:ffi/ffi.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:intl/intl.dart';
import 'package:postek_printer/printer_services.dart';
import 'package:win32/win32.dart';

Future<PrintResult> computePrintDoubleLabelAsImage(
  Uint8List imageBytes,
  String printerName,
) async {
  return await Isolate.run(() async {
    Pointer<IntPtr>? hPrinter;
    Pointer<Utf16>? printerNamePtr;
    Pointer<Uint8>? dataPtr;
    Pointer<DOC_INFO_1>? docInfo;
    Pointer<Utf16>? docNamePtr;
    Pointer<Utf16>? dataTypePtr;

    try {
      hPrinter = calloc<IntPtr>();
      printerNamePtr = printerName.toNativeUtf16();

      final openSuccess = OpenPrinter(printerNamePtr, hPrinter, nullptr);
      if (openSuccess == 0) {
        return PrintResult(success: false, error: 'Gagal membuka printer "$printerName".');
      }

      docNamePtr = 'Label Image Print'.toNativeUtf16();
      dataTypePtr = 'RAW'.toNativeUtf16();

      docInfo = calloc<DOC_INFO_1>()
        ..ref.pDocName = docNamePtr
        ..ref.pOutputFile = nullptr
        ..ref.pDatatype = dataTypePtr;

      if (StartDocPrinter(hPrinter.value, 1, docInfo.cast()) == 0) {
        return PrintResult(success: false, error: 'Gagal memulai dokumen.');
      }

      if (StartPagePrinter(hPrinter.value) == 0) {
        return PrintResult(success: false, error: 'Gagal memulai halaman.');
      }

      final written = calloc<Uint32>();
      dataPtr = calloc.allocate<Uint8>(imageBytes.length);
      final nativeBytes = dataPtr.asTypedList(imageBytes.length);
      nativeBytes.setAll(0, imageBytes);

      final writeSuccess = WritePrinter(hPrinter.value, dataPtr.cast(), imageBytes.length, written);
      if (writeSuccess == 0 || written.value == 0) {
        return PrintResult(success: false, error: 'Gagal mengirim data ke printer.');
      }

      EndPagePrinter(hPrinter.value);
      EndDocPrinter(hPrinter.value);
      ClosePrinter(hPrinter.value);

      return PrintResult(success: true);
    } catch (e) {
      return PrintResult(success: false, error: "Error: $e");
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
