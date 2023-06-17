// ignore_for_file: avoid_print

import 'dart:convert' show JsonEncoder, json;
import 'dart:io' show Directory, File, FileSystemEntity;

import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:svelte_ast/svelte_ast.dart'
    show CssMode, ParseError, SvelteAst, parse;

const DeepCollectionEquality equality = DeepCollectionEquality.unordered();

const JsonEncoder encoder = JsonEncoder.withIndent('\t');

void main() {
  Uri uri = Uri(path: 'test/parser/samples');
  Directory directory = Directory.fromUri(uri);

  for (FileSystemEntity sample in directory.listSync()) {
    File file;
    String content;

    Map<String, Object?>? options;
    SvelteAst ast;

    Object? actual, expected;

    try {
      CssMode? cssMode;
      file = File.fromUri(sample.uri.resolve('options.json'));

      if (file.existsSync()) {
        content = file.readAsStringSync();
        options = json.decode(content) as Map<String, Object?>?;

        if (options != null) {
          if (options['css'] is String) {
            cssMode = CssMode.values.byName(options['css'] as String);
          }
        }
      }

      file = File.fromUri(sample.uri.resolve('input.svelte'));
      content = file.readAsStringSync();
      ast = parse(content, uri: file.uri, cssMode: cssMode);
      actual = ast.toJson();

      file = File.fromUri(sample.uri.resolve('output.json'));

      if (file.existsSync()) {
        expected = json.decode(file.readAsStringSync());
      } else {
        print('error expected ${sample.path}');
        continue;
      }
    } on ParseError catch (error) {
      actual = error.toJson();
      file = File.fromUri(sample.uri.resolve('error.json'));

      if (file.existsSync()) {
        expected = json.decode(file.readAsStringSync());
      } else {
        print('output expected ${sample.path}');
        continue;
      }
    } catch (error) {
      print(error);
      continue;
    }

    if (equality.equals(actual, expected)) {
      continue;
    }

    file.writeAsStringSync(encoder.convert(actual));
  }
}
