import 'dart:ffi';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:intl/intl.dart';
import 'package:postek_printer/component/snackbar.dart';
import 'package:postek_printer/printer_services_image.dart';
import 'package:win32/win32.dart';
import 'package:postek_printer/printer_services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PosLabel Printer',
      scaffoldMessengerKey: AppSnackbar.scaffoldKey,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  List<String> _printerList = [];
  String? _selectedPrinter;
  final TextEditingController _idPotong = TextEditingController(text: 'P-12345678');
  final TextEditingController _sku = TextEditingController(text: 'NAMABARANG_WARNA_UKURAN');
  final TextEditingController _jumlahCetak = TextEditingController(text: '1');

  Future<List<String>> getPrinters() async {
    return Future(() {
      // FFI hanya bisa dipakai di Windows
      if (!Platform.isWindows) {
        AppSnackbar.show(message: "List printer ini hanya tersedia di Windows via USB", type: "error");
        return [];
      }
      final flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;
      final pcbNeeded = calloc<Uint32>();
      final pcReturned = calloc<Uint32>();
      final printers = <String>[];

      // Panggilan pertama untuk mendapatkan ukuran buffer
      EnumPrinters(flags, nullptr, 2, nullptr, 0, pcbNeeded, pcReturned);

      if (pcbNeeded.value > 0) {
        final pPrinterEnum = calloc<Uint8>(pcbNeeded.value);

        final success = EnumPrinters(
          flags,
          nullptr,
          2,
          pPrinterEnum,
          pcbNeeded.value,
          pcbNeeded,
          pcReturned,
        );

        if (success != 0) {
          final count = pcReturned.value;
          final structSize = sizeOf<PRINTER_INFO_2>();

          for (var i = 0; i < count; i++) {
            final info = Pointer<PRINTER_INFO_2>.fromAddress(
              pPrinterEnum.address + (i * structSize),
            ).ref;

            final name = info.pPrinterName.toDartString();
            printers.add(name);
          }
        }

        calloc.free(pPrinterEnum);
      }

      calloc.free(pcbNeeded);
      calloc.free(pcReturned);

      print("List printer: $printers");
      AppSnackbar.show(message: "LIST PRINTER : $printers", type: "success");
      return printers;
    });
  }

  Future<Uint8List?> renderLabelToImageBytes(LabelPrintParams params) async {
    final formattedTanggal = DateFormat('ddMMyy').format(DateTime.now());

    final boundary = RenderRepaintBoundary();
    final pipelineOwner = PipelineOwner();
    final buildOwner = BuildOwner(focusManager: FocusManager());

    final labelWidget = Directionality(
      textDirection: ui.TextDirection.ltr,
      child: buildLabelWidget(params, formattedTanggal),
    );

    final renderAdapter = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: labelWidget,
    );

    final element = renderAdapter.attachToRenderTree(buildOwner);
    buildOwner.buildScope(element);
    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }


  @override
  void initState() {
    getPrinters().then((printers) {
      setState(() {
        _printerList = printers;
        _selectedPrinter = printers.isNotEmpty ? printers.first : null;
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text("POSTEK C-168/200s")),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final printers = await getPrinters();
                      setState(() {
                        _printerList = printers;
                        _selectedPrinter = printers.isNotEmpty ? printers.first : null;
                      });
                    } catch (e) {
                      AppSnackbar.show(message: "Gagal memuat printer: $e", type: "error");
                      print("Gagal memuat printer: $e");
                    }
                  },

                  icon: const Icon(Icons.refresh),
                  label: const Text('REFRESH PRINTER'),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_selectedPrinter == null) {
                      AppSnackbar.show(message: "Pilih printer terlebih dahulu", type: "error");
                      return;
                    }
                    try {
                      await cancelAllPrintJobs(_selectedPrinter!);
                      AppSnackbar.show(message: "Semua print job dibatalkan", type: "success");
                    } catch (e) {
                      AppSnackbar.show(message: "Gagal membatalkan: $e", type: "error");
                    }
                  },
                  icon: const Icon(Icons.cancel),
                  label: const Text("BATALKAN PROSES PRINT"),
                ),

              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPrinter,
                decoration: const InputDecoration(labelText: 'PRINTER :',labelStyle: TextStyle(fontWeight: FontWeight.bold)),
                items: _printerList.map((printer) {
                  return DropdownMenuItem(
                    value: printer,
                    child: Text(printer),
                  );
                }).toList(),
                onChanged: (value) {
                  print("Selected printer: $value");
                  setState(() {
                    _selectedPrinter = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _idPotong,
                decoration: const InputDecoration(labelText: 'ID POTONG :',labelStyle: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _sku,
                decoration: const InputDecoration(labelText: 'KODE / SKU :',labelStyle: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _jumlahCetak,
                decoration: const InputDecoration(
                  labelText: 'JUMLAH CETAK :',
                  labelStyle: TextStyle(fontWeight: FontWeight.bold),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,  // Memastikan hanya angka yang diterima
                ],
              ),
              const SizedBox(height: 30),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_selectedPrinter == null) {
                      AppSnackbar.show( message: "Pilih printer terlebih dahulu", type: "error");
                      return;
                    }

                    final sku1 = _idPotong.text.trim();
                    final idPotong1 = _sku.text.trim();
                    final sku2 = sku1;
                    final idPotong2 = idPotong1;
                    var jumlah = int.tryParse(_jumlahCetak.text.trim()) ?? 1;
                    if (jumlah <= 0) jumlah = 1;

                    if (sku1.isEmpty || idPotong1.isEmpty) {
                      AppSnackbar.show( message: "Semua form wajib diisi", type: "error");
                      return;
                    }

                    final result = await computePrintDoubleLabel(LabelPrintParams(
                      printerName: _selectedPrinter!,
                      skuKiri: sku1,
                      idPotongKiri: idPotong1,
                      skuKanan: sku2,
                      idPotongKanan: idPotong2,
                      jumlah: jumlah,
                    ));

                    if (result.success) {
                      AppSnackbar.show(message: "Label berhasil dicetak", type: "success");
                    } else {
                      AppSnackbar.show(
                        message: result.error ?? "Gagal mencetak",
                        type: "error",
                      );
                    }

                  },
                  icon: const Icon(Icons.print),
                  label: const Text('CETAK LABEL (TSLP)'),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_selectedPrinter == null) {
                      AppSnackbar.show( message: "Pilih printer terlebih dahulu", type: "error");
                      return;
                    }

                    final sku1 = _idPotong.text.trim();
                    final idPotong1 = _sku.text.trim();
                    final sku2 = sku1;
                    final idPotong2 = idPotong1;
                    var jumlah = int.tryParse(_jumlahCetak.text.trim()) ?? 1;
                    if (jumlah <= 0) jumlah = 1;

                    if (sku1.isEmpty || idPotong1.isEmpty) {
                      AppSnackbar.show( message: "Semua form wajib diisi", type: "error");
                      return;
                    }

                    final imageBytes = await renderLabelToImageBytes(LabelPrintParams(
                      printerName: _selectedPrinter!,
                      skuKiri: sku1,
                      idPotongKiri: idPotong1,
                      skuKanan: sku2,
                      idPotongKanan: idPotong2,
                      jumlah: jumlah,
                    ));

                    if (imageBytes != null) {
                      final result = await computePrintDoubleLabelAsImage(imageBytes, _selectedPrinter!);
                      print(result.success ? "Berhasil print!" : result.error);
                    } else {
                      AppSnackbar.show(message: "Gagal merender label ke gambar", type: "error");
                      return;
                    }

                  },
                  icon: const Icon(Icons.print),
                  label: const Text('CETAK LABEL (IMAGE)'),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
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


}

