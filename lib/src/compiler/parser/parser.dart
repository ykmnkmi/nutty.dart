import 'package:source_span/source_span.dart' show SourceFile;
import 'package:svelte/src/compiler/interface.dart';
import 'package:svelte/src/compiler/parser/errors.dart';
import 'package:svelte/src/compiler/parser/state/fragment.dart';

final RegExp spaceRe = RegExp('[ \t\r\n]');

class AutoCloseTag {
  AutoCloseTag(this.tag, this.reason, this.depth);

  String? tag;

  String reason;

  int depth;
}

class Parser {
  Parser(String template, {Object? sourceUrl})
      : template = template.trimRight(),
        sourceFile = SourceFile.fromString(template, url: sourceUrl) {
    stack.add(html);

    while (isNotDone) {
      fragment();
    }

    if (stack.length > 1) {
      var current = this.current;

      String type, slug;

      if (current.type == 'Element') {
        type = '<${current.name}>';
        slug = 'element';
      } else {
        type = 'Block';
        slug = 'block';
      }

      error(code: 'unclose-$slug', message: '$type was left open.');
    }

    var children = html.children;

    if (children != null && children.isNotEmpty) {
      var start = children.first.start ?? 0;

      while (spaceRe.hasMatch(template[start])) {
        start += 1;
      }

      html.start = start;

      var end = children.last.end ?? template.length;

      while (spaceRe.hasMatch(template[end - 1])) {
        end -= 1;
      }

      html.end = end;
    }
  }

  final String template;

  final SourceFile sourceFile;

  final Node html = Node(type: 'Fragment', children: <Node>[]);

  final List<Script> scripts = <Script>[];

  final Set<String> metaTags = <String>{};

  final List<Node> stack = <Node>[];

  int position = 0;

  AutoCloseTag? lastAutoCloseTag;

  Node get current {
    return stack.last;
  }

  bool get isNotDone {
    return position < template.length;
  }

  bool get isDone {
    return position == template.length;
  }

  void allowSpace({bool require = false}) {
    var match = spaceRe.matchAsPrefix(template, position);

    if (match == null) {
      if (require) {
        error(code: 'missing-whitespace', message: 'Expected whitespace');
      }

      return;
    }

    position = match.end;
  }

  bool match(Pattern pattern) {
    var match = pattern.matchAsPrefix(template, position);
    return match != null;
  }

  bool scan(Pattern pattern) {
    var match = pattern.matchAsPrefix(template, position);

    if (match == null) {
      return false;
    }

    position = match.end;
    return true;
  }

  void expect(Pattern pattern, [Never Function()? onError]) {
    var match = pattern.matchAsPrefix(template, position);

    if (match == null) {
      if (onError == null) {
        if (isNotDone) {
          unexpectedToken(pattern, position);
        }

        unexpectedEofToken(pattern);
      }

      onError();
    }

    position = match.end;
  }

  String? read(Pattern pattern) {
    var match = pattern.matchAsPrefix(template, position);

    if (match == null) {
      return null;
    }

    position = match.end;
    return match[0];
  }

  String readUntil(Pattern pattern, [Never Function()? onError]) {
    var found = template.indexOf(pattern, position);

    if (found == -1) {
      if (isNotDone) {
        return template.substring(position, position = template.length);
      }

      if (onError == null) {
        unexpectedEof();
      }

      onError();
    }

    return template.substring(position, position = found);
  }

  Never error({required String code, required String message, int? position}) {
    var span = sourceFile.span(position ?? this.position);
    throw ParseError(code, message, span);
  }
}