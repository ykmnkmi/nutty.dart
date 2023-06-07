// ignore_for_file: depend_on_referenced_packages, implementation_imports

import 'package:_fe_analyzer_shared/src/scanner/token.dart'
    show Token, TokenType;
import 'package:svelte_ast/src/ast.dart';
import 'package:svelte_ast/src/parser.dart';
import 'package:svelte_ast/src/scanner.dart';
import 'package:svelte_ast/src/state/mustache.dart';
import 'package:svelte_ast/src/state/text.dart';

extension TagParser on Parser {
  Node? tag() {
    Token open = expectToken(TokenType.LT);
    Token tagNameToken = expectToken(SvelteToken.TAG_IDENTIFIER);
    String tagName = tagNameToken.lexeme;

    skipNextTokenIf(SvelteToken.TAG_SPACE);

    List<Node> body = _body(tagName, (token) {
      return token.type == SvelteToken.TAG_IDENTIFIER &&
          token.lexeme == tagName;
    });

    skipNextTokenIf(SvelteToken.TAG_SPACE);
    Token close = expectToken(TokenType.GT);
    return Element(
        start: open.offset, end: close.end, name: tagName, body: body);
  }

  List<Node> _body(String tag, bool Function(Token token) end) {
    expectToken(TokenType.GT);

    List<Node> nodes = <Node>[];
    String endTag = '$tag-${token.offset}';
    endTagsStack.add(endTag);

    outer:
    while (token.type != TokenType.EOF) {
      if (token.type == SvelteToken.LT_SLASH) {
        Token next = token.next!;

        if (end(next)) {
          token = next.next!;
          break outer;
        }
      } else if (token.type == TokenType.OPEN_CURLY_BRACKET) {
        nodes.add(mustache());
      } else if (token.type == SvelteToken.DATA) {
        nodes.add(text());
      } else {
        throw UnimplementedError(token.lexeme);
      }
    }

    if (endTagsStack.isEmpty || endTagsStack.last != endTag) {
      throw StateError('Expected token type $tag, got ${token.lexeme}.');
    } else {
      endTagsStack.removeLast();
    }

    if (token.type == TokenType.EOF) {
      throw StateError('EOF');
    }

    return nodes;
  }
}