import 'dart:io';
import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/doc_page.dart';

/// Service for exporting pages to various formats (PDF, DOCX, EPUB)
class ExportService {
  /// Export a single page to PDF format
  Future<File> exportPageToPdf(DocPage page, String outputPath) async {
    final pdf = pw.Document();
    
    // Convert HTML to plain text for PDF (simplified)
    final plainText = _htmlToPlainText(page.htmlContent);
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  page.title,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Created: ${_formatDate(page.createdAt)}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
              pw.Text(
                'Updated: ${_formatDate(page.updatedAt)}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
              if (page.tags.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Text(
                  'Tags: ${page.tags.join(", ")}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.blue),
                ),
              ],
              pw.SizedBox(height: 20),
              pw.Expanded(
                child: pw.Text(
                  plainText,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
    
    return _writeExportFile(outputPath, await pdf.save());
  }

  /// Export multiple pages to a single PDF
  Future<File> exportPagesToPdf(List<DocPage> pages, String outputPath) async {
    final pdf = pw.Document();
    
    for (final page in pages) {
      final plainText = _htmlToPlainText(page.htmlContent);
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    page.title,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Created: ${_formatDate(page.createdAt)}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
                pw.Text(
                  'Updated: ${_formatDate(page.updatedAt)}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
                if (page.tags.isNotEmpty) ...[
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Tags: ${page.tags.join(", ")}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.blue),
                  ),
                ],
                pw.SizedBox(height: 20),
                pw.Expanded(
                  child: pw.Text(
                    plainText,
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
    
    return _writeExportFile(outputPath, await pdf.save());
  }

  /// Export a single page to EPUB format
  Future<File> exportPageToEpub(DocPage page, String outputPath) async {
    return exportPagesToEpub([page], outputPath, title: page.title);
  }

  /// Export multiple pages to EPUB format
  Future<File> exportPagesToEpub(
    List<DocPage> pages,
    String outputPath, {
    String title = 'Docume Export',
  }) async {
    final archive = Archive();
    
    // Add mimetype file (required for EPUB)
    archive.addFile(ArchiveFile(
      'mimetype',
      20,
      'application/epub+zip'.codeUnits,
    ));
    
    // Add META-INF/container.xml
    archive.addFile(ArchiveFile(
      'META-INF/container.xml',
      _containerXml.length,
      _containerXml.codeUnits,
    ));
    
    // Add content.opf
    final contentOpf = _generateContentOpf(pages, title);
    archive.addFile(ArchiveFile(
      'OEBPS/content.opf',
      contentOpf.length,
      contentOpf.codeUnits,
    ));
    
    // Add toc.ncx
    final tocNcx = _generateTocNcx(pages, title);
    archive.addFile(ArchiveFile(
      'OEBPS/toc.ncx',
      tocNcx.length,
      tocNcx.codeUnits,
    ));
    
    // Add chapters
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final chapterHtml = _generateChapterHtml(page, i);
      archive.addFile(ArchiveFile(
        'OEBPS/chapter${i + 1}.xhtml',
        chapterHtml.length,
        chapterHtml.codeUnits,
      ));
    }
    
    // Add basic CSS
    archive.addFile(ArchiveFile(
      'OEBPS/style.css',
      _styleCss.length,
      _styleCss.codeUnits,
    ));
    
    // Encode to ZIP
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);
    
    return _writeExportFile(outputPath, zipData!);
  }

  /// Export a single page to DOCX format
  Future<File> exportPageToDocx(DocPage page, String outputPath) async {
    return exportPagesToDocx([page], outputPath);
  }

  /// Export multiple pages to DOCX format
  Future<File> exportPagesToDocx(List<DocPage> pages, String outputPath) async {
    final archive = Archive();
    
    // Add [Content_Types].xml
    archive.addFile(ArchiveFile(
      '[Content_Types].xml',
      _contentTypesXml.length,
      _contentTypesXml.codeUnits,
    ));
    
    // Add _rels/.rels
    archive.addFile(ArchiveFile(
      '_rels/.rels',
      _relsXml.length,
      _relsXml.codeUnits,
    ));
    
    // Add word/_rels/document.xml.rels
    archive.addFile(ArchiveFile(
      'word/_rels/document.xml.rels',
      _documentRelsXml.length,
      _documentRelsXml.codeUnits,
    ));
    
    // Add word/document.xml
    final documentXml = _generateDocumentXml(pages);
    archive.addFile(ArchiveFile(
      'word/document.xml',
      documentXml.length,
      documentXml.codeUnits,
    ));
    
    // Encode to ZIP
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);
    
    return _writeExportFile(outputPath, zipData!);
  }

  /// Get a suggested filename for export
  String getSuggestedFilename(DocPage page, String extension) {
    final sanitizedTitle = page.title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    return '${sanitizedTitle}_${page.id.substring(0, 8)}.$extension';
  }

  /// Get a suggested filename for multiple pages export
  String getSuggestedBulkFilename(String extension) {
    final timestamp = DateTime.now().toIso8601String().split('T')[0];
    return 'docume_export_$timestamp.$extension';
  }

  // Helper methods

  Future<File> _writeExportFile(String outputPath, List<int> bytes) async {
    final file = File(outputPath);
    final parentDir = file.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }
    await file.writeAsBytes(bytes);
    return file;
  }

  String _htmlToPlainText(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'</(p|div|h[1-6]|li)>'), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'\n\s*\n'), '\n\n')
        .trim();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // EPUB generation helpers

  String _generateContentOpf(List<DocPage> pages, String title) {
    final manifest = pages
        .asMap()
        .entries
        .map((e) => '<item id="chapter${e.key + 1}" href="chapter${e.key + 1}.xhtml" media-type="application/xhtml+xml"/>')
        .join('\n    ');
    
    final spine = pages
        .asMap()
        .entries
        .map((e) => '<itemref idref="chapter${e.key + 1}"/>')
        .join('\n    ');
    
    return '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="uid">docume-${DateTime.now().millisecondsSinceEpoch}</dc:identifier>
    <dc:title>$title</dc:title>
    <dc:language>en</dc:language>
    <dc:creator>Docume</dc:creator>
    <meta property="dcterms:modified">${DateTime.now().toIso8601String()}</meta>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="style" href="style.css" media-type="text/css"/>
    $manifest
  </manifest>
  <spine toc="ncx">
    $spine
  </spine>
</package>''';
  }

  String _generateTocNcx(List<DocPage> pages, String title) {
    final navPoints = pages
        .asMap()
        .entries
        .map((e) => '''<navPoint id="navpoint-${e.key + 1}" playOrder="${e.key + 1}">
      <navLabel>
        <text>${_escapeXml(e.value.title)}</text>
      </navLabel>
      <content src="chapter${e.key + 1}.xhtml"/>
    </navPoint>''')
        .join('\n    ');
    
    return '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="docume-${DateTime.now().millisecondsSinceEpoch}"/>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
  </head>
  <docTitle>
    <text>$title</text>
  </docTitle>
  <navMap>
    $navPoints
  </navMap>
</ncx>''';
  }

  String _generateChapterHtml(DocPage page, int index) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head>
  <title>${_escapeXml(page.title)}</title>
  <link rel="stylesheet" type="text/css" href="style.css"/>
</head>
<body>
  <h1>${_escapeXml(page.title)}</h1>
  <p class="metadata">Created: ${_formatDate(page.createdAt)} | Updated: ${_formatDate(page.updatedAt)}</p>
  ${page.tags.isNotEmpty ? '<p class="tags">Tags: ${page.tags.map(_escapeXml).join(", ")}</p>' : ''}
  <div class="content">
    ${page.htmlContent}
  </div>
</body>
</html>''';
  }

  // DOCX generation helpers

  String _generateDocumentXml(List<DocPage> pages) {
    final paragraphs = pages.map((page) {
      final plainText = _htmlToPlainText(page.htmlContent);
      return '''
    <w:p>
      <w:pPr>
        <w:pStyle w:val="Heading1"/>
      </w:pPr>
      <w:r>
        <w:t>${_escapeXml(page.title)}</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:r>
        <w:rPr>
          <w:sz w:val="18"/>
          <w:color w:val="666666"/>
        </w:rPr>
        <w:t>Created: ${_formatDate(page.createdAt)} | Updated: ${_formatDate(page.updatedAt)}</w:t>
      </w:r>
    </w:p>
    ${page.tags.isNotEmpty ? '''<w:p>
      <w:r>
        <w:rPr>
          <w:sz w:val="18"/>
          <w:color w:val="0000FF"/>
        </w:rPr>
        <w:t>Tags: ${page.tags.join(", ")}</w:t>
      </w:r>
    </w:p>''' : ''}
    ${plainText.split('\n').map((line) => '''<w:p>
      <w:r>
        <w:t>${_escapeXml(line)}</w:t>
      </w:r>
    </w:p>''').join('\n    ')}
    <w:p/>''';
    }).join('\n');
    
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $paragraphs
  </w:body>
</w:document>''';
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  // Static XML templates

  static const _containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';

  static const _styleCss = '''body {
  font-family: Georgia, serif;
  font-size: 1em;
  line-height: 1.6;
  margin: 2em;
}

h1 {
  font-size: 2em;
  margin-bottom: 0.5em;
  color: #333;
}

.metadata {
  font-size: 0.9em;
  color: #666;
  margin-bottom: 1em;
}

.tags {
  font-size: 0.9em;
  color: #0066cc;
  margin-bottom: 2em;
}

.content {
  margin-top: 2em;
}

p {
  margin-bottom: 1em;
}''';

  static const _contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

  static const _relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

  static const _documentRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''';
}
