import 'dart:ffi';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ffi/ffi.dart';
import 'package:postek_printer/component/snackbar.dart';
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

  List<String> _printerList = ["Dummy Printer"];
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
      AppSnackbar.show(message: "List printer: $printers", type: "success");
      return printers;
    });
  }

  @override
  void initState() {
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
                decoration: const InputDecoration(labelText: 'JUMLAH CETAK :',labelStyle: TextStyle(fontWeight: FontWeight.bold)),
                keyboardType: TextInputType.number,
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
                      AppSnackbar.show( message: "SKU & kode potong wajib diisi", type: "error");
                      return;
                    }

                    final result = await computePrintDoubleLabel(LabelPrintParams(
                      printerName: _selectedPrinter!,
                      sku1: sku1,
                      idPotong1: idPotong1,
                      sku2: sku2,
                      idPotong2: idPotong2,
                      jumlah: jumlah,
                    ));

                    if (result.success) {
                      AppSnackbar.show(message: "Mencetak berhasil", type: "success");
                    } else {
                      AppSnackbar.show(
                        message: result.error ?? "Gagal mencetak",
                        type: "error",
                      );
                    }

                  },
                  icon: const Icon(Icons.print),
                  label: const Text('CETAK LABEL 2 KOLOM'),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }


}

