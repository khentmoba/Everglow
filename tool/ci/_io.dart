import 'dart:convert';
import 'dart:io';

Future<String> readTolerant(File f) =>
    f.readAsBytes().then((b) => utf8.decode(b, allowMalformed: true));
