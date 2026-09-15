import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/books/data/models/book_item.dart';
import 'package:everglow/features/books/data/services/epub_service.dart';

/// Builds a minimal valid EPUB in memory: container.xml + OPF with a
/// two-item spine + two XHTML chapters.
Uint8List buildTestEpub() {
  final archive = Archive();
  void add(String name, String text) {
    final bytes = utf8.encode(text);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('mimetype', 'application/epub+zip');
  add(
    'META-INF/container.xml',
    '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''',
  );
  add(
    'OEBPS/content.opf',
    '''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata><dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Test Book</dc:title></metadata>
  <manifest>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="ch2.xhtml" media-type="application/xhtml+xml"/>
    <item id="cover" href="cover.jpg" media-type="image/jpeg"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
  </spine>
</package>''',
  );
  add(
    'OEBPS/ch1.xhtml',
    '''<?xml version="1.0"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>The Beginning</title></head>
<body><h1>The Beginning</h1><p>It was a bright day &amp; the birds sang.</p><p>Second paragraph here.</p></body></html>''',
  );
  add(
    'OEBPS/ch2.xhtml',
    '''<?xml version="1.0"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>The End</title></head>
<body><script>var x = 1;</script><style>p { color: red; }</style><h2>The End</h2><p>And so it ended.<br/>Truly.</p></body></html>''',
  );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

BookItem bookWithIa(String iaId) => BookItem(
  id: '',
  workKey: '/works/OL1W',
  iaId: iaId,
  title: 'Test',
  status: '',
  addedAt: DateTime(2024),
);

void main() {
  group('EpubService.parseChapters', () {
    test('extracts spine chapters in order with titles', () {
      final chapters = EpubService.parseChapters(buildTestEpub());
      expect(chapters.length, 2);
      expect(chapters[0].title, 'The Beginning');
      expect(chapters[1].title, 'The End');
    });

    test('strips tags, scripts, and styles but keeps paragraphs', () {
      final chapters = EpubService.parseChapters(buildTestEpub());
      expect(chapters[0].body.contains('<'), isFalse);
      expect(chapters[0].body.contains('bright day & the birds'), isTrue);
      expect(chapters[0].body.contains('Second paragraph'), isTrue);
      expect(chapters[1].body.contains('var x'), isFalse);
      expect(chapters[1].body.contains('color: red'), isFalse);
      expect(chapters[1].body.contains('And so it ended.'), isTrue);
    });

    test('skips non-XHTML manifest items (cover image)', () {
      final chapters = EpubService.parseChapters(buildTestEpub());
      expect(chapters.length, 2);
    });

    test('returns empty for a zip with no OPF', () {
      final archive = Archive();
      final bytes = utf8.encode('hello');
      archive.addFile(ArchiveFile('random.txt', bytes.length, bytes));
      final zip = Uint8List.fromList(ZipEncoder().encode(archive));
      expect(EpubService.parseChapters(zip), isEmpty);
    });
  });

  group('EpubService.htmlToText', () {
    test('turns block ends into paragraph breaks', () {
      final text = EpubService.htmlToText('<p>One</p><p>Two</p>');
      expect(text, 'One\n\nTwo');
    });

    test('unescapes entities', () {
      expect(EpubService.htmlToText('<p>A &amp; B</p>'), 'A & B');
      expect(EpubService.htmlToText('<p>&#65;BC</p>'), 'ABC');
    });
  });

  group('EpubService.candidatesFor', () {
    test('gutenberg ids map to gutenberg EPUB urls', () {
      final urls = EpubService().candidatesFor(bookWithIa('pg1342'));
      expect(urls.length, 2);
      expect(urls.first.contains('gutenberg.org'), isTrue);
      expect(urls.first.contains('1342'), isTrue);
    });

    test('archive ids map to the item epub file', () {
      final urls = EpubService().candidatesFor(bookWithIa('somebookid'));
      expect(urls, ['https://archive.org/download/somebookid/somebookid.epub']);
    });

    test('books without an id have no candidates', () {
      expect(EpubService().candidatesFor(bookWithIa('')), isEmpty);
    });
  });
}
