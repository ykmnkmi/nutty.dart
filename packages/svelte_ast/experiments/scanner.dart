// ignore_for_file: constant_identifier_names, depend_on_referenced_packages

import 'package:_fe_analyzer_shared/src/scanner/characters.dart';
import 'package:_fe_analyzer_shared/src/scanner/scanner.dart';
import 'package:_fe_analyzer_shared/src/scanner/token.dart';
import 'package:_fe_analyzer_shared/src/scanner/token_constants.dart';
import 'package:analyzer/dart/analysis/features.dart' show FeatureSet;
import 'package:analyzer/src/dart/scanner/scanner.dart' as dart show Scanner;

enum ScannerState {
  dart,
  data,
}

class SvelteToken extends StringToken {
  static const TokenType DATA =
      TokenType(152, 'data', 'DATA', NO_PRECEDENCE, STRING_TOKEN);

  SvelteToken(this.type, String value, int offset) : super(type, value, offset);

  @override
  final TokenType type;
}

class SvelteStringScanner extends StringScanner {
  factory SvelteStringScanner.latest(String string) {
    FeatureSet featureSet = FeatureSet.latestLanguageVersion();
    ScannerConfiguration configuration = dart.Scanner.buildConfig(featureSet);
    return SvelteStringScanner(string, configuration: configuration);
  }

  SvelteStringScanner(super.string, {super.configuration})
      : state = ScannerState.data,
        super(includeComments: true);

  ScannerState state;

  @override
  int bigSwitch(int next) {
    beginToken();
    if (identical(next, $SPACE) ||
        identical(next, $TAB) ||
        identical(next, $LF) ||
        identical(next, $CR)) {
      appendWhiteSpace(next);
      next = advance();
      // Sequences of spaces are common, so advance through them fast.
      while (identical(next, $SPACE)) {
        // We don't invoke [:appendWhiteSpace(next):] here for efficiency,
        // assuming that it does not do anything for space characters.
        next = advance();
      }
      return next;
    }

    int nextLower = next | 0x20;

    if ($a <= nextLower && nextLower <= $z) {
      if (identical($r, next)) {
        return tokenizeRawStringKeywordOrIdentifier(next);
      }
      return tokenizeKeywordOrIdentifier(next, /* allowDollar = */ true);
    }

    if (identical(next, $CLOSE_PAREN)) {
      return appendEndGroup(TokenType.CLOSE_PAREN, OPEN_PAREN_TOKEN);
    }

    if (identical(next, $OPEN_PAREN)) {
      appendBeginGroup(TokenType.OPEN_PAREN);
      return advance();
    }

    if (identical(next, $SEMICOLON)) {
      appendPrecedenceToken(TokenType.SEMICOLON);
      // Type parameters and arguments cannot contain semicolon.
      discardOpenLt();
      return advance();
    }

    if (identical(next, $PERIOD)) {
      return tokenizeDotsOrNumber(next);
    }

    if (identical(next, $COMMA)) {
      appendPrecedenceToken(TokenType.COMMA);
      return advance();
    }

    if (identical(next, $EQ)) {
      return tokenizeEquals(next);
    }

    if (identical(next, $CLOSE_CURLY_BRACKET)) {
      int next = appendEndGroup(
          TokenType.CLOSE_CURLY_BRACKET, OPEN_CURLY_BRACKET_TOKEN);

      if (groupingStack.isEmpty) {
        state = ScannerState.data;
      }

      return next;
    }

    if (identical(next, $SLASH)) {
      return tokenizeSlashOrComment(next);
    }

    if (identical(next, $OPEN_CURLY_BRACKET)) {
      appendBeginGroup(TokenType.OPEN_CURLY_BRACKET);
      return advance();
    }

    if (identical(next, $DQ) || identical(next, $SQ)) {
      return tokenizeString(next, scanOffset, /* raw = */ false);
    }

    if (identical(next, $_)) {
      return tokenizeKeywordOrIdentifier(next, /* allowDollar = */ true);
    }

    if (identical(next, $COLON)) {
      appendPrecedenceToken(TokenType.COLON);
      return advance();
    }

    if (identical(next, $LT)) {
      return tokenizeLessThan(next);
    }

    if (identical(next, $GT)) {
      return tokenizeGreaterThan(next);
    }

    if (identical(next, $BANG)) {
      return tokenizeExclamation(next);
    }

    if (identical(next, $OPEN_SQUARE_BRACKET)) {
      return tokenizeOpenSquareBracket(next);
    }

    if (identical(next, $CLOSE_SQUARE_BRACKET)) {
      return appendEndGroup(
          TokenType.CLOSE_SQUARE_BRACKET, OPEN_SQUARE_BRACKET_TOKEN);
    }

    if (identical(next, $AT)) {
      return tokenizeAt(next);
    }

    if (next >= $1 && next <= $9) {
      return tokenizeNumber(next);
    }

    if (identical(next, $AMPERSAND)) {
      return tokenizeAmpersand(next);
    }

    if (identical(next, $0)) {
      return tokenizeHexOrNumber(next);
    }

    if (identical(next, $QUESTION)) {
      return tokenizeQuestion(next);
    }

    if (identical(next, $BAR)) {
      return tokenizeBar(next);
    }

    if (identical(next, $PLUS)) {
      return tokenizePlus(next);
    }

    if (identical(next, $$)) {
      return tokenizeKeywordOrIdentifier(next, /* allowDollar = */ true);
    }

    if (identical(next, $MINUS)) {
      return tokenizeMinus(next);
    }

    if (identical(next, $STAR)) {
      return tokenizeMultiply(next);
    }

    if (identical(next, $CARET)) {
      return tokenizeCaret(next);
    }

    if (identical(next, $TILDE)) {
      return tokenizeTilde(next);
    }

    if (identical(next, $PERCENT)) {
      return tokenizePercent(next);
    }

    if (identical(next, $BACKPING)) {
      appendPrecedenceToken(TokenType.BACKPING);
      return advance();
    }

    if (identical(next, $BACKSLASH)) {
      appendPrecedenceToken(TokenType.BACKSLASH);
      return advance();
    }

    if (identical(next, $HASH)) {
      return tokenizeTag(next);
    }

    if (next < 0x1f) {
      return unexpected(next);
    }

    next = currentAsUnicode(next);

    return unexpected(next);
  }

  @override
  Token tokenize() {
    int next = advance();
    int start = scanOffset;

    while (!identical(next, $EOF)) {
      if (state == ScannerState.dart) {
        next = bigSwitch(next);
        start = scanOffset;
      } else {
        if (identical(next, $OPEN_CURLY_BRACKET)) {
          String value = string.substring(start, scanOffset);
          appendToken(SvelteToken(SvelteToken.DATA, value, start));
          state = ScannerState.dart;
        } else {
          next = advance();
        }
      }
    }

    if (start < scanOffset) {
      String value = string.substring(start, scanOffset);
      appendToken(SvelteToken(SvelteToken.DATA, value, start));
      state = ScannerState.dart;
    }

    if (atEndOfFile()) {
      appendEofToken();
    } else {
      unexpectedEof();
    }

    // Always pretend that there's a line at the end of the file.
    lineStarts.add(stringOffset + 1);
    return firstToken();
  }
}
