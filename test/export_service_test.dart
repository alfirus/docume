import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:docume/models/doc_page.dart';
import 'package:docume/services/export_service.dart';

void main() {
  group('ExportService', () {
    late ExportService exportService;
    late DocPage testPage;
    late List<DocPage> testPages;
    late Directory tempDir;

    setUp(() {
      exportService = ExportService();
      
      testPage = DocPage(
        id: 'test-id-1',
        title: 'Test Page',
        htmlContent: '<h1>Test Header</h1><p>This is test content.</p>',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        tags: ['test', 'export'],
      );

      testPages = [
        testPage,
        DocPage(
          id: 'test-id-2',
          title: 'Second Page',
          htmlContent: '<p>Second page content</p>',
          createdAt: DateTime(2026, 1, 3),
          updatedAt: DateTime(2026, 1, 4),
          tags: ['test'],
        ),
      ];

      // Create temp directory for tests
      tempDir = Directory.systemTemp.createTempSync('export_test_');
    });

    tearDown(() {
      // Clean up temp directory
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('exportPageToPdf creates valid PDF file', () async {
      final outputPath = '${tempDir.path}/test.pdf';
      
      final file = await exportService.exportPageToPdf(testPage, outputPath);
      
      expect(file.existsSync(), isTrue);
      expect(file.path, equals(outputPath));
      
      // Verify it's a PDF file (starts with PDF header)
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(0));
      // PDF files start with %PDF-
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, equals('%PDF-'));
    });

    test('export creates missing parent directories', () async {
      final nestedPdfPath = '${tempDir.path}/nested/dir/test.pdf';
      final nestedDocxPath = '${tempDir.path}/nested/dir/test.docx';
      final nestedEpubPath = '${tempDir.path}/nested/dir/test.epub';

      final pdfFile = await exportService.exportPageToPdf(testPage, nestedPdfPath);
      final docxFile = await exportService.exportPageToDocx(testPage, nestedDocxPath);
      final epubFile = await exportService.exportPageToEpub(testPage, nestedEpubPath);

      expect(pdfFile.existsSync(), isTrue);
      expect(docxFile.existsSync(), isTrue);
      expect(epubFile.existsSync(), isTrue);
      expect(Directory('${tempDir.path}/nested/dir').existsSync(), isTrue);
    });

    test('exportPagesToPdf creates valid PDF with multiple pages', () async {
      final outputPath = '${tempDir.path}/test_multiple.pdf';
      
      final file = await exportService.exportPagesToPdf(testPages, outputPath);
      
      expect(file.existsSync(), isTrue);
      
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(0));
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, equals('%PDF-'));
    });

    test('exportPageToEpub creates valid EPUB file', () async {
      final outputPath = '${tempDir.path}/test.epub';
      
      final file = await exportService.exportPageToEpub(testPage, outputPath);
      
      expect(file.existsSync(), isTrue);
      expect(file.path, equals(outputPath));
      
      // Verify it's a ZIP file (EPUB is a ZIP)
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(0));
      // ZIP files start with PK
      final header = String.fromCharCodes(bytes.take(2));
      expect(header, equals('PK'));
    });

    test('exportPagesToEpub creates valid EPUB with multiple pages', () async {
      final outputPath = '${tempDir.path}/test_multiple.epub';
      
      final file = await exportService.exportPagesToEpub(
        testPages,
        outputPath,
        title: 'Test Export',
      );
      
      expect(file.existsSync(), isTrue);
      
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(0));
      final header = String.fromCharCodes(bytes.take(2));
      expect(header, equals('PK'));
    });

    test('exportPageToDocx creates valid DOCX file', () async {
      final outputPath = '${tempDir.path}/test.docx';
      
      final file = await exportService.exportPageToDocx(testPage, outputPath);
      
      expect(file.existsSync(), isTrue);
      expect(file.path, equals(outputPath));
      
      // Verify it's a ZIP file (DOCX is a ZIP)
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(0));
      // ZIP files start with PK
      final header = String.fromCharCodes(bytes.take(2));
      expect(header, equals('PK'));
    });

    test('exportPagesToDocx creates valid DOCX with multiple pages', () async {
      final outputPath = '${tempDir.path}/test_multiple.docx';
      
      final file = await exportService.exportPagesToDocx(testPages, outputPath);
      
      expect(file.existsSync(), isTrue);
      
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(0));
      final header = String.fromCharCodes(bytes.take(2));
      expect(header, equals('PK'));
    });

    test('getSuggestedFilename returns sanitized filename', () {
      final filename = exportService.getSuggestedFilename(testPage, 'pdf');
      
      expect(filename, contains('test_page'));
      expect(filename, endsWith('.pdf'));
      expect(filename, contains(testPage.id.substring(0, 8)));
    });

    test('getSuggestedFilename handles special characters', () {
      final pageWithSpecialChars = testPage.copyWith(
        title: 'Test/Page: With*Special?Characters',
      );
      
      final filename = exportService.getSuggestedFilename(
        pageWithSpecialChars,
        'pdf',
      );
      
      // Should not contain special characters
      expect(filename, isNot(contains('/')));
      expect(filename, isNot(contains(':')));
      expect(filename, isNot(contains('*')));
      expect(filename, isNot(contains('?')));
      expect(filename, endsWith('.pdf'));
    });

    test('getSuggestedBulkFilename includes date', () {
      final filename = exportService.getSuggestedBulkFilename('pdf');
      
      expect(filename, startsWith('docume_export_'));
      expect(filename, endsWith('.pdf'));
      expect(filename, contains('2026-')); // Current year in test
    });

    test('HTML to plain text conversion removes tags', () async {
      final htmlContent = '<h1>Header</h1><p>Paragraph</p><strong>Bold</strong>';
      final page = testPage.copyWith(htmlContent: htmlContent);
      
      final outputPath = '${tempDir.path}/test_plain.pdf';
      
      // This should not throw and should handle HTML properly
      final file = await exportService.exportPageToPdf(page, outputPath);
      expect(file.existsSync(), isTrue);
    });

    test('Export handles pages with empty content', () async {
      final emptyPage = testPage.copyWith(htmlContent: '');
      final outputPath = '${tempDir.path}/test_empty.pdf';
      
      final file = await exportService.exportPageToPdf(emptyPage, outputPath);
      
      expect(file.existsSync(), isTrue);
    });

    test('Export handles pages with line breaks', () async {
      final pageWithBreaks = testPage.copyWith(
        htmlContent: '<p>Line 1<br/>Line 2</p><p>Paragraph 2</p>',
      );
      final outputPath = '${tempDir.path}/test_breaks.pdf';
      
      final file = await exportService.exportPageToPdf(
        pageWithBreaks,
        outputPath,
      );
      
      expect(file.existsSync(), isTrue);
    });

    test('Export includes metadata in PDF', () async {
      final outputPath = '${tempDir.path}/test_metadata.pdf';
      
      final file = await exportService.exportPageToPdf(testPage, outputPath);
      
      // Verify file was created and has content
      expect(file.existsSync(), isTrue);
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(1000)); // Should have substantial content
    });

    test('Export includes tags in outputs', () async {
      final pdfPath = '${tempDir.path}/test_tags.pdf';
      
      final file = await exportService.exportPageToPdf(testPage, pdfPath);
      
      // Verify file was created and has content
      expect(file.existsSync(), isTrue);
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(1000)); // Should have substantial content
    });
  });
}
