// THROWAWAY. Delete this file, its entry point, and the
// google_mlkit_barcode_scanning dependency once the spike question is
// answered. See docs/superpowers/specs/2026-09-08-id-extraction-spike.md.
//
// It answers one question: do these physical cards carry machine-readable
// data (AAMVA PDF417, ICAO MRZ), or must extraction be OCR heuristics?

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/data/attachments/scanner/document_scanner.dart';

/// The shape of an ICAO 9303 machine-readable zone line.
final _mrzLine = RegExp(r'^[A-Z0-9<]{30,44}$');

/// AAMVA payloads carry this marker in their header.
const _aamvaMarker = 'ANSI ';

/// AAMVA data elements are three-letter codes at the start of a line.
final _aamvaElement = RegExp(r'^([A-Z]{3})(.*)$');

class IdProbeScreen extends ConsumerStatefulWidget {
  const IdProbeScreen({super.key});

  @override
  ConsumerState<IdProbeScreen> createState() => _IdProbeScreenState();
}

class _IdProbeScreenState extends ConsumerState<IdProbeScreen> {
  final _lines = <String>[];
  bool _busy = false;

  Future<void> _probe() async {
    setState(() {
      _busy = true;
      _lines.clear();
    });

    final pages = await ref.read(documentScannerProvider).scan();
    if (!mounted) return;
    if (pages.isEmpty) {
      setState(() {
        _busy = false;
        _lines.add('cancelled - no pages');
      });
      return;
    }

    final barcodes = BarcodeScanner();
    final text = TextRecognizer();
    final out = <String>[];

    for (var i = 0; i < pages.length; i++) {
      out.add('--- page ${i + 1} (${pages[i].bytes.length} bytes) ---');

      // ML Kit needs a file: InputImage.fromBytes wants raw planes, not JPEG.
      // So the plaintext image touches disk here, and is deleted immediately
      // in the finally below. That exposure is acceptable for a throwaway
      // probe, and is exactly why the shipped scanner passes BYTES instead.
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'probe-$i.jpg'));
      try {
        await file.writeAsBytes(pages[i].bytes);
        final input = InputImage.fromFilePath(file.path);
        out.addAll(await _summariseBarcodes(barcodes, input));
        out.addAll(await _summariseText(text, input));
      } catch (e) {
        out.add('  ERROR: $e');
      } finally {
        if (file.existsSync()) {
          await file.delete();
        }
      }
    }

    await barcodes.close();
    await text.close();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lines.addAll(out);
    });
  }

  /// STRUCTURE ONLY.
  ///
  /// A licence barcode payload is the holder's name, date of birth, address
  /// and licence number. Printing it would put identity data on screen and,
  /// from there, into whatever this summary gets pasted into. Field VALUES are
  /// replaced by their lengths, which still answers the spike's question.
  Future<List<String>> _summariseBarcodes(
    BarcodeScanner scanner,
    InputImage input,
  ) async {
    final found = await scanner.processImage(input);
    if (found.isEmpty) {
      return ['  barcode: NONE'];
    }

    final out = <String>[];
    for (final b in found) {
      final raw = b.rawValue ?? '';
      out.add('  barcode: ${b.format.name}, ${raw.length} chars');
      final isAamva = raw.contains(_aamvaMarker);
      out.add('    AAMVA header: ${isAamva ? 'YES' : 'no'}');
      if (isAamva) {
        final codes = <String, int>{};
        for (final line in raw.split(RegExp(r'[\r\n]+'))) {
          final m = _aamvaElement.firstMatch(line.trim());
          if (m != null) {
            codes[m.group(1)!] = m.group(2)!.length;
          }
        }
        out.add('    fields (code:valueLength): '
            '${codes.entries.map((e) => '${e.key}:${e.value}').join(' ')}');
      }
    }
    return out;
  }

  Future<List<String>> _summariseText(
    TextRecognizer recognizer,
    InputImage input,
  ) async {
    final result = await recognizer.processImage(input);
    final lines = [
      for (final block in result.blocks)
        for (final line in block.lines) line.text.trim(),
    ];
    final mrz = lines.where(_mrzLine.hasMatch).length;
    return [
      '  ocr: ${result.blocks.length} blocks, ${lines.length} lines',
      '    MRZ-shaped lines: $mrz',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DEV - ID probe')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Structure only - no field values are shown, so this summary is '
              'safe to share verbatim. Nothing is kept on disk: the temp file '
              'ML Kit needs is deleted immediately.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('idProbeScanButton'),
              onPressed: _busy ? null : _probe,
              child: Text(_busy ? 'Scanning...' : 'Scan a card'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _lines.isEmpty ? '(no results yet)' : _lines.join('\n'),
                  style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
