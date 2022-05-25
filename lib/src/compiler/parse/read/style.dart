import 'package:piko/src/compiler/interface.dart';
import 'package:piko/src/compiler/parse/parse.dart';
import 'package:piko/src/compiler/parse/errors.dart';

extension StyleParser on Parser {
  static final RegExp styleCloseTagRe = RegExp(r'<\/style\s*>');

  void style(int start, List<Node>? attributes) {
    var content = readUntil(styleCloseTagRe, unclosedStyle);

    if (scan(styleCloseTagRe)) {
      styles.add(Style(start: start, end: index, lang: 'css', content: content));
      return;
    }

    unclosedStyle();
  }
}
