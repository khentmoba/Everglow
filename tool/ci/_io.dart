import 'dart:convert';
import 'dart:io';

// Lenient read: one non-UTF8 source file (extended-ASCII) must not break
// the scan; all markers the guards look for are ASCII.
Future<String> readTolerant(File f) =>
    f.readAsBytes().then((b) => utf8.decode(b, allowMalformed: true));
