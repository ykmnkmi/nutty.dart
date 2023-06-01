// ignore_for_file: depend_on_referenced_packages

import 'package:_fe_analyzer_shared/src/scanner/token.dart' show Token;
import 'package:svelte_ast/src/ast.dart';

import '../parser.dart';
import '../scanner.dart';

extension TextParser on Parser {
  Text? text() {
    Token token = expectToken(SvelteToken.DATA);
    String value = token.lexeme;

    if (value.isEmpty) {
      return null;
    }

    return Text(start: token.offset, end: token.end, raw: value, data: value);
  }
}
