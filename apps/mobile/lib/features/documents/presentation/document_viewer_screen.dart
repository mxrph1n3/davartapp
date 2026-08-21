import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/ds/ds.dart';
import 'documents_notifier.dart';

class DocumentViewerScreen extends ConsumerStatefulWidget {
  const DocumentViewerScreen({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  PdfControllerPinch? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pdfAsync = ref.watch(documentPdfBytesProvider(widget.documentId));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppBackButton(fallback: AppRoutes.projects),
        title: const Text('Документ'),
      ),
      body: pdfAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Не удалось открыть PDF')),
        data: (bytes) {
          _controller ??= PdfControllerPinch(
            document: PdfDocument.openData(Uint8List.fromList(bytes)),
          );

          return PdfViewPinch(controller: _controller!);
        },
      ),
    );
  }
}
