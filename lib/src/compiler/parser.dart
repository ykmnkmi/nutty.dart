import 'errors.dart';
import 'nodes.dart';

part 'parser/expression.dart';
part 'parser/tag.dart';

Fragment parse(String template) {
  final parser = Parser(template);
  return parser.root;
}

typedef State = String? Function();

class LastAutoClosedTag {
  final String tag;

  final String reason;

  final int depth;

  LastAutoClosedTag(this.tag, this.reason, this.depth);
}

class Parser {
  final String template;

  final List<List<Node>> stack;

  final Fragment root;

  int index;

  Parser(this.template)
      : stack = <List<Node>>[],
        root = Fragment(),
        index = 0 {
    stack.add(root);

    while (!isDone) {
      if (match('<')) {
        tag();
      } else if (match('{')) {
        mustache();
      } else {
        text();
      }
    }

    if (stack.length > 1) {
      error(code: 'unexpected-eof', message: 'unexpected end of input');
    }
  }

  List<Node> get current {
    return stack.last;
  }

  bool get isDone {
    return index >= template.length;
  }

  bool get isEmpty {
    return stack.isEmpty;
  }

  bool get isNotEmpty {
    return stack.isNotEmpty;
  }

  int get length {
    return stack.length;
  }

  String get rest {
    return template.substring(index);
  }

  void add(Node node) {
    current.add(node);
  }

  bool eat(String string, {bool required = false, String? message}) {
    if (match(string)) {
      index += string.length;
      return true;
    }

    if (required) {
      error(code: 'unexpected-${isDone ? 'eof' : 'token'}', message: message ?? "expected '$string'");
    }

    return false;
  }

  Never error({String? code, String? message}) {
    final start = index - 10 < 0 ? 0 : index - 10;
    final end = index + 10 < template.length ? index + 10 : template.length;
    throw CompileError(code: code, message: message, source: template.substring(start, end), offset: index - start);
  }

  String? look(Pattern pattern) {
    final match = pattern.matchAsPrefix(template, index);
    return match?[0];
  }

  bool match(Pattern pattern) {
    return pattern.matchAsPrefix(template, index) != null;
  }

  void mustache() {
    eat('{', required: true);
    whitespace();
    expression();
    whitespace();
    eat('}', required: true);
  }

  void pop() {
    stack.removeLast();
  }

  void push([NodeList? nodeList]) {
    stack.add(nodeList ?? NodeList());
  }

  String? read(Pattern regExp) {
    final result = look(regExp);

    if (result != null) {
      index += result.length;
    }

    return result;
  }

  String readUntil(Pattern pattern) {
    if (isDone) {
      error(message: 'unexpected end of input');
    }

    final start = index;
    final end = template.indexOf(pattern, index);

    if (end > 0) {
      index = end;
      return template.substring(start, end);
    }

    index = template.length;
    return template.substring(start);
  }

  void skip(Pattern? pattern) {
    if (pattern == null) {
      return;
    }

    final result = look(pattern);

    if (result != null) {
      index += result.length;
    }
  }

  void skipUntil(Pattern pattern) {
    if (isDone) {
      error(message: 'unexpected end of input');
    }

    final end = template.indexOf(pattern, index);

    if (end > 0) {
      index = end;
      return;
    }

    index = template.length;
  }

  void text() {
    final start = index;

    while (!isDone && !match('{') && !match('<')) {
      index += 1;
    }

    if (start != index) {
      add(Text(template.substring(start, index)));
    }
  }

  void whitespace({bool required = false}) {
    const whitespaces = <String>[' ', '\t', '\r', '\n'];

    if (required && whitespaces.contains(template[index])) {
      error(code: 'missing-whitespace', message: 'expected whitespace');
    }

    while (!isDone && whitespaces.contains(template[index])) {
      index += 1;
    }
  }
}
