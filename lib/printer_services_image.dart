import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:postek_printer/printer_services.dart';
import 'package:win32/win32.dart';

Future<PrintResult> computePrintDoubleLabelAsImage(LabelPrintParams params) async {
  return await Isolate.run(() async {
    Pointer<IntPtr>? hPrinter;
    Pointer<Utf16>? printerNamePtr;
    Pointer<Uint8>? dataPtr;
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
        return PrintResult(success: false, error: 'Gagal memulai halaman printer.');
      }

      // Bangun widget di layar offscreen
      final boundary = RenderRepaintBoundary();
      final pipelineOwner = PipelineOwner();
      final buildOwner = BuildOwner(focusManager: FocusManager());

      final formattedTanggal = DateFormat('ddMMyy').format(DateTime.now());

      final labelWidget = Directionality(
        textDirection: ui.TextDirection.ltr,
        child: buildLabelWidget(params, formattedTanggal),
      );

      final renderObjectToWidgetAdapter = RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
        child: labelWidget,
      );

      final element = renderObjectToWidgetAdapter.attachToRenderTree(buildOwner);
      buildOwner.buildScope(element);
      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return PrintResult(success: false, error: 'Gagal membuat gambar dari widget.');
      }

      final Uint8List imageBytes = byteData.buffer.asUint8List();
      final written = calloc<Uint32>();
      dataPtr = calloc.allocate<Uint8>(imageBytes.length);
      final nativeBytes = dataPtr.asTypedList(imageBytes.length);
      nativeBytes.setAll(0, imageBytes);

      final writeSuccess = WritePrinter(hPrinter.value, dataPtr.cast(), imageBytes.length, written);
      if (writeSuccess == 0 || written.value == 0) {
        return PrintResult(success: false, error: 'Gagal mengirim data gambar ke printer.');
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

Widget buildLabelWidget(LabelPrintParams params, String tanggal) {
  return Container(
    width: 800, // 100 mm
    height: 160, // 20 mm
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Row(
      children: [
        Expanded(
          child: buildSingleLabel(params.skuKiri, params.idPotongKiri, tanggal),
        ),
        Expanded(
          child: buildSingleLabel(params.skuKanan, params.idPotongKanan, tanggal),
        ),
      ],
    ),
  );
}

Widget buildSingleLabel(String sku, String idPotong, String tanggal) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text("YOUNIQ EXCLUSIVE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      SizedBox(height: 5),
      BarcodeWidget(
        barcode: Barcode.code128(),
        data: sku,
        width: 180,
        height: 40,
      ),
      SizedBox(height: 5),
      Text(sku, style: TextStyle(fontSize: 14)),
      Text('$tanggal/$idPotong', style: TextStyle(fontSize: 12)),
    ],
  );
}
