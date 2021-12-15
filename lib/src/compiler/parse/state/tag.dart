import 'package:analyzer/dart/ast/standard_ast_factory.dart' show astFactory;
import 'package:analyzer/dart/ast/token.dart' show Token, TokenType;
import 'package:piko/src/compiler/parse/errors.dart';
import 'package:piko/src/compiler/parse/read/expression.dart';

import '../../utils/html.dart';
import '../../utils/names.dart';
import '../../utils/patterns.dart';
import '../../interface.dart';
import '../parse.dart';

extension TagParser on Parser {
  static const Map<String, String> metaTags = <String, String>{
    'svelte:head': 'Head',
    'svelte:options': 'Options',
    'svelte:window': 'Window',
    'svelte:body': 'Body',
  };

  static const Set<String> validMetaTags = <String>{
    'svelte:head',
    'svelte:options',
    'svelte:window',
    'svelte:body',
    'svelte:self',
    'svelte:component',
    'svelte:fragment',
  };

  static late final RegExp validTagNameRe = compile(r'^\!?[a-zA-Z]{1,}:?[a-zA-Z0-9\-]*');

  static late final RegExp selfRe = compile(r'^svelte:self(?=[\s/>])');

  static late final RegExp componentRe = compile(r'^svelte:component(?=[\s/>])');

  static late final RegExp slotRe = compile(r'^svelte:fragment(?=[\s/>])');

  static late final RegExp componentNameRe = compile('^[A-Z].*');

  static late final RegExp tagNameRe = compile(r'(\s|\/|>)');

  static late final RegExp attributeNameRe = compile(r'[\s=\/>"' ']');

  static late final RegExp quoteRe = compile(r'["' "']");

  static late final RegExp attributeValueEndRe = compile(r'(\/>|[\s"' "'=<>`])");

  bool parentIsHead() {
    for (var node in stack.reversed) {
      var type = node.type;

      if (type == 'Head') {
        return true;
      }

      if (type == 'Element' || type == 'InlineComponent') {
        return false;
      }
    }

    return false;
  }

  void tag() {
    var start = index;

    expect('<');

    var parent = current;

    if (scan('!--')) {
      var data = readUntil('-->');

      if (scan('-->')) {
        current.addChild(Node(start: start, end: index, type: 'Comment', data: data));
        return;
      }

      error('unclosed-comment', 'comment was left open, expected -->');
    }

    var isClosingTag = scan('/');
    var name = readTagName();
    var slug = metaTags[name];

    if (slug != null) {
      slug = slug.toLowerCase();

      if (isClosingTag) {
        if ((name == 'svelte:window' || name == 'svelte:body') && current.children.isNotEmpty) {
          error('invalid-$slug-content', '<$name> cannot have children', position: current.children.first.start);
        }
      } else {
        if (this.metaTags.contains(name)) {
          error('duplicate-$slug', 'a component can only have one <$name> tag', position: start);
        }

        if (stack.length > 1) {
          error('invalid-$slug-placement', '<$name> cannot be inside elements or blocks', position: start);
        }

        this.metaTags.add(name);
      }
    }

    var type = metaTags[name];

    if (type == null) {
      if (componentNameRe.hasMatch(name) || name == 'svelte:self' || name == 'svelte:component') {
        type = 'InlineComponent';
      } else if (name == 'svelte:fragment') {
        type = 'SlotTemplate';
      } else if (name == 'title' && parentIsHead()) {
        type = 'Title';
      } else if (name == 'slot') {
        type = 'Slot';
      } else {
        type = 'Element';
      }
    }

    var element = Node(start: start, type: type, name: name);

    allowWhitespace();

    if (isClosingTag) {
      if (isVoid(name)) {
        var message = '<$name> is a void element and cannot have children, or a closing tag';
        error('invalid-void-content', message, position: start);
      }

      expect('>');

      var lastClosedTag = lastAutoClosedTag;

      while (parent.name != name) {
        if (parent.type != 'Element') {
          var code = 'invalid-closing-tag';
          var prefix = '</$name> attempted to close';

          if (lastClosedTag != null && lastClosedTag.tag == name) {
            var message = '$prefix $name that was already automatically closed by ${lastClosedTag.reason}';
            error(code, message, position: start);
          }

          var message = '$prefix an element that was not open';
          error(code, message, position: start);
        }

        parent.end = start;
        stack.removeLast();
        parent = current;
      }

      parent.end = index;
      stack.removeLast();

      if (lastClosedTag != null && stack.length < lastClosedTag.depth) {
        lastAutoClosedTag = null;
      }

      return;
    } else if (closingTagOmitted(parent.name, name)) {
      parent.end = start;
      stack.removeLast();
      lastAutoClosedTag = LastAutoClosedTag(name, name, stack.length);
    }

    var uniqueNames = <String>{};
    var attribute = readAttribute(uniqueNames);

    while (attribute != null) {
      element.addAttribute(attribute);

      allowWhitespace();

      attribute = readAttribute(uniqueNames);
    }

    if (name == 'svelte:component') {
      Node definition;

      component:
      {
        var attributes = element.attributes;

        if (attributes != null) {
          for (var attribute in attributes) {
            if (attribute.type == 'Attribute' && attribute.name == 'this') {
              definition = attribute;
              break component;
            }
          }
        }

        missingComponentDefinition(start);
      }

      var children = definition.children;

      if (children.length != 1 || children.first.type == 'Text') {
        invalidComponentDefinition(definition.start);
      }

      element.expression = children.first.expression;
    }

    // TODO: top-level script/style parsing

    current.addChild(element);

    var selfClosing = scan('/') || isVoid(name);

    expect('>');

    if (selfClosing) {
      element.end = index;
    } else if (name == 'textarea') {
      var pattern = compile(r'^<\/textarea(\s[^>]*)?>');
      element.children = readSequence(pattern);
      scan(pattern);
      element.end = index;
    } else if (name == 'script' || name == 'style') {
      var start = index;
      var data = readUntil('</$name>');
      element.addChild(Node(start: start, end: index, type: 'Text', data: data));
      expect('</$name>');
      element.end = index;
    } else {
      stack.add(element);
    }
  }

  String readTagName() {
    var start = index;

    if (scan(selfRe)) {
      legal:
      {
        for (var fragment in stack.reversed) {
          var type = fragment.type;

          if (type == 'IfBlock' || type == 'EachBlock' || type == 'InlineComponent') {
            break legal;
          }
        }

        invalidSelfPlacement(start);
      }

      return 'svelte:self';
    }

    if (scan(componentRe)) {
      return 'svelte:component';
    }

    if (scan(slotRe)) {
      return 'svelte:fragment';
    }

    var name = readUntil(tagNameRe);
    var meta = metaTags[name];

    if (meta != null) {
      return meta;
    }

    if (name.startsWith('svelte:')) {
      invalidTagNameSvelteElement(validMetaTags, start);
    }

    if (!validTagNameRe.hasMatch(name)) {
      invalidTagName(start);
    }

    return name;
  }

  Node? readAttribute(Set<String> uniqueNames) {
    var start = index;

    void checkUnique(String name) {
      if (uniqueNames.contains(name)) {
        duplicateAttribute(start);
      }

      uniqueNames.add(name);
    }

    if (scan('{')) {
      allowWhitespace();

      if (scan('...')) {
        var expression = readExpression();

        allowWhitespace();
        expect('}');

        return Node(start: start, end: index, type: 'Spread', expression: expression);
      } else {
        var valueStart = index;
        var name = readIdentifier();

        allowWhitespace();
        expect('}');

        if (name == null) {
          emptyAttributeShorthand(start);
        }

        checkUnique(name);
        var tokenType = TokenType(name, 'IDENTIFIER', 0, 97);
        var token = Token(tokenType, valueStart);
        var identifier = astFactory.simpleIdentifier(token);
        var end = valueStart + name.length;
        var shortHand = Node(start: valueStart, end: end, type: 'AttributeShorthand', expression: identifier);
        return Node(start: start, end: index, type: 'Attribute', name: name, children: <Node>[shortHand]);
      }
    }

    var name = readUntil(attributeNameRe);

    if (name.isEmpty) {
      return null;
    }

    var end = index;

    allowWhitespace();

    var colonIndex = name.indexOf(':');
    String? type;

    if (colonIndex != -1) {
      type = getDirectiveType(name.substring(0, colonIndex));
    }

    List<Node>? value;

    if (scan('=')) {
      allowWhitespace();

      value = readAttributeValue();
      end = index;
    } else if (match(quoteRe)) {
      unexpectedToken('=', start);
    }

    if (type != null) {
      var modifiers = name.substring(colonIndex + 1).split('|');
      var directiveName = modifiers.removeAt(0);

      if (directiveName.isEmpty) {
        emptyDirectiveName(type, start + colonIndex + 1);
      }

      if (type == 'Binding' || directiveName != 'this') {
        checkUnique(directiveName);
      } else if (type != 'Eventhandler' || type != 'Action') {
        checkUnique(directiveName);
      }

      if (type == 'Ref') {
        invalidRefDirective(name, start);
      }

      if (value != null && value.isNotEmpty) {
        if (value.length > 1 || value.first.type == 'Text') {
          invalidDirectiveValue(value.first.start);
        }
      }

      var directive = Node(start: start, end: end, type: type, name: directiveName, modifiers: modifiers);

      if (value != null && value.isNotEmpty) {
        directive.expression = value.first.expression;
      }

      if (type == 'Transition') {
        var direction = name.substring(0, colonIndex);
        directive.intro = direction == 'in' || direction == 'transition';
        directive.outro = direction == 'out' || direction == 'transition';
      }

      if (value == null && (type == 'Binding' || type == 'Class')) {
        var tokenType = TokenType(directiveName, 'IDENTIFIER', 0, 97);
        var token = Token(tokenType, directive.start! + colonIndex + 1);
        directive.expression = astFactory.simpleIdentifier(token);
      }

      return directive;
    }

    checkUnique(name);
    return Node(start: start, end: end, type: 'Attribute', name: name, children: value);
  }

  List<Node> readAttributeValue() {
    var quoteMark = read(quoteRe);

    if (quoteMark != null && scan(quoteMark)) {
      return <Node>[Node(start: index - 1, end: index - 1, type: 'Text')];
    }

    var regex = quoteMark ?? attributeValueEndRe;
    // TODO(error): test for unclosedAttributeValue
    var value = readSequence(regex);

    if (value.isEmpty && quoteMark == null) {
      missingAttributeValue();
    }

    if (quoteMark != null) {
      expect(quoteMark);
    }

    return value;
  }

  List<Node> readSequence(Pattern pattern) {
    var buffer = StringBuffer();
    var chunks = <Node>[];

    void flush(int start, int end) {
      if (buffer.isNotEmpty) {
        chunks.add(Node(start: start, end: end, type: 'Text', data: buffer.toString()));
        buffer.clear();
      }
    }

    while (canParse) {
      var start = index;

      if (match(pattern)) {
        flush(start, index);
        return chunks;
      }

      if (scan('{')) {
        flush(start, index - 1);

        allowWhitespace();

        var expression = readExpression();

        allowWhitespace();
        expect('}');

        chunks.add(Node(start: start, end: index, type: 'MustacheTag', expression: expression));
      } else {
        buffer.writeCharCode(readChar());
      }
    }

    unexpectedEOF();
  }

  static String? getDirectiveType(String name) {
    switch (name) {
      case 'use':
        return 'Action';
      case 'animate':
        return 'Animation';
      case 'bind':
        return 'Binding';
      case 'class':
        return 'Class';
      case 'on':
        return 'EventHandler';
      case 'let':
        return 'Let';
      case 'ref':
        return 'Ref';
      case 'in':
      case 'out':
      case 'transition':
        return 'Transition';
      default:
        return null;
    }
  }
}
