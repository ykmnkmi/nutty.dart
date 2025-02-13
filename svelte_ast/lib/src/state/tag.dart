// ignore_for_file: unused_import

import 'package:analyzer/dart/ast/ast.dart';
import 'package:source_span/source_span.dart';
import 'package:svelte_ast/src/ast.dart';
import 'package:svelte_ast/src/errors.dart';
import 'package:svelte_ast/src/extract_svelte_ignore.dart';
import 'package:svelte_ast/src/html.dart';
import 'package:svelte_ast/src/names.dart';
import 'package:svelte_ast/src/parser.dart';
import 'package:svelte_ast/src/patterns.dart';
import 'package:svelte_ast/src/read/expression.dart';
import 'package:svelte_ast/src/read/script.dart';
import 'package:svelte_ast/src/read/style.dart';

final RegExp _self = RegExp('svelte:self(?=[\\s/>])');

final RegExp _component = RegExp('svelte:component(?=[\\s/>])');

final RegExp _element = RegExp('svelte:element(?=[\\s/>])');

final RegExp _slot = RegExp('svelte:fragment(?=[\\s/>])');

final RegExp _validTagNameRe = RegExp('^\\!?[a-zA-Z]{1,}:?[a-zA-Z0-9\\-]*');

final RegExp _tagNameEndRe = RegExp('(\\s|\\/|>)');

final RegExp _tokenEndingCharacter = RegExp('[\\s=\\/>"\']');

final RegExp _startsWithQuoteCharacters = RegExp('["\']');

final RegExp _startsWithInvalidAttributeValue = RegExp('(\\/>|[\\s"\'=<>`])');

final RegExp _capitalLetter = RegExp('^[A-Z]');

final RegExp _nonCharRe = RegExp('[^A-Za-z]');

final RegExp _textareaCloseTag = RegExp(
  '<\\/textarea(\\s[^>]*)?>',
  caseSensitive: false,
);

const Map<String, String> _metaTags = <String, String>{
  'svelte:head': 'Head',
  'svelte:options': 'Options',
  'svelte:window': 'Window',
  'svelte:document': 'Document',
  'svelte:body': 'Body',
};

const List<String> _validMetaTags = <String>[
  'svelte:head',
  'svelte:options',
  'svelte:window',
  'svelte:document',
  'svelte:body',
  'svelte:self',
  'svelte:component',
  'svelte:fragment',
  'svelte:element',
];

DirectiveType? _getDirectiveType(String name) {
  return switch (name) {
    'use' => DirectiveType.action,
    'animate' => DirectiveType.animation,
    'bind' => DirectiveType.binding,
    'class' => DirectiveType.classDirective,
    'style' => DirectiveType.styleDirective,
    'on' => DirectiveType.eventHandler,
    'let' => DirectiveType.let,
    'ref' => DirectiveType.ref,
    'in' || 'out' || 'transition' => DirectiveType.transition,
    _ => null,
  };
}

bool _parentIsHead(List<Node> stack) {
  for (Node node in stack.reversed) {
    if (node is Head) {
      return true;
    }

    if (node is Element || node is InlineComponent) {
      return true;
    }
  }

  return false;
}

extension TagParser on Parser {
  String _readTagName() {
    int start = position;

    if (scan(_self)) {
      bool legal = false;

      for (Node node in stack.reversed) {
        if (node is IfBlock || node is EachBlock || node is InlineComponent) {
          legal = true;
          break;
        }
      }

      if (!legal) {
        error(invalidSelfPlacement, start);
      }

      return 'svelte:self';
    }

    if (scan(_component)) {
      return 'svelte:component';
    }

    if (scan(_element)) {
      return 'svelte:element';
    }

    if (scan(_slot)) {
      return 'svelte:fragment';
    }

    String name = readUntil(_tagNameEndRe);

    if (_metaTags.containsKey(name)) {
      return name;
    }

    if (name.startsWith('svelte:')) {
      error(
        invalidTagNameSvelteElement(_validMetaTags),
        start,
        start + name.length,
      );
    }

    if (_validTagNameRe.hasMatch(name)) {
      return name;
    }

    error(invalidTagName, start);
  }

  Node? _readAttribute(Set<String> uniqueNames) {
    int start = position;

    void checkUnique(String name) {
      if (uniqueNames.contains(name)) {
        error(duplicateAttribute, start);
      }

      uniqueNames.add(name);
    }

    if (scan(openingCurlyRe)) {
      if (scan('...')) {
        Expression expression = readExpression(closingCurlyRe);
        allowSpace();
        expect('}');
        return Spread(start: start, end: position, expression: expression);
      } else {
        if (scan(closingCurlyRe)) {
          error(emptyAttributeShorthand, start);
        }

        int valueStart = position;
        Expression expression = readExpression(closingCurlyRe);

        String name = switch (expression) {
          SimpleIdentifier(:String name) => name,
          _ => throw UnimplementedError(),
        };

        checkUnique(name);

        allowSpace();
        expect('}');

        return Attribute(
          start: start,
          end: position,
          name: name,
          values: <Node>[
            AttributeShorthand(
              start: valueStart,
              end: valueStart + name.length,
              expression: expression,
            ),
          ],
        );
      }
    }

    String name = readUntil(_tokenEndingCharacter);

    if (name.isEmpty) {
      return null;
    }

    int end = position;
    allowSpace();

    int colonIndex = name.indexOf(':');
    DirectiveType? type;

    if (colonIndex != -1) {
      type = _getDirectiveType(name.substring(0, colonIndex));
    }

    List<Node> values = <Node>[];

    if (scan('=')) {
      allowSpace();
      values = _readAttributeValue();
      end = position;
    } else if (match(_startsWithQuoteCharacters)) {
      error(unexpectedToken('='), position);
    }

    if (type != null) {
      var <String>[String directiveName, ...List<String> modifiers] = name
          .substring(colonIndex + 1)
          .split('|');

      if (directiveName.isEmpty) {
        error(emptyDirectiveName(type.name), start + colonIndex + 1);
      }

      if (type == DirectiveType.binding && directiveName != 'this') {
        checkUnique(directiveName);
      } else if (type != DirectiveType.eventHandler &&
          type != DirectiveType.action) {
        checkUnique(name);
      }

      if (type == DirectiveType.ref) {
        error(invalidRefDirective(name), start);
      }

      if (type == DirectiveType.styleDirective) {
        return StyleDirective(
          start: start,
          end: end,
          name: directiveName,
          modifiers: modifiers,
          values: values,
        );
      }

      Expression? expression;

      if (values.isNotEmpty) {
        Node first = values.first;

        if (first is Text || values.length > 1) {
          error(invalidDirectiveValue, first.start);
        }

        if (first is MustacheTag) {
          expression = first.expression;
        }
      }

      switch (type) {
        case DirectiveType.action:
          return Action(
            start: start,
            end: end,
            name: directiveName,
            modifiers: modifiers,
            expression: expression,
          );

        case DirectiveType.animation:
          return Animation(
            start: start,
            end: end,
            name: directiveName,
            modifiers: modifiers,
            expression: expression,
          );

        case DirectiveType.binding:
          return Binding(
            start: start,
            end: end,
            name: directiveName,
            modifiers: modifiers,
            expression:
                expression ??
                simpleIdentifier(start + colonIndex + 1, directiveName),
          );

        case DirectiveType.classDirective:
          return ClassDirective(
            start: start,
            end: end,
            name: directiveName,
            modifiers: modifiers,
            expression:
                expression ??
                simpleIdentifier(start + colonIndex + 1, directiveName),
          );

        case DirectiveType.eventHandler:
          return EventHandler(
            start: start,
            end: end,
            name: directiveName,
            modifiers: modifiers,
            expression: expression,
          );

        case DirectiveType.let:
          return Let(
            start: start,
            end: end,
            name: directiveName,
            modifiers: modifiers,
            expression: expression,
          );

        case DirectiveType.ref:
          return Ref(
            start: start,
            end: end,
            name: directiveName,
            modifiers: modifiers,
            expression: expression,
          );

        case DirectiveType.transition:
          String direction = name.substring(0, colonIndex);
          return TransitionDirective(
            start: start,
            end: end,
            name: directiveName,
            modifiers: modifiers,
            intro: direction == 'in' || direction == 'transition',
            outro: direction == 'out' || direction == 'transition',
            expression: expression,
          );

        default:
          throw UnimplementedError(type.name);
      }
    }

    checkUnique(name);
    return Attribute(start: start, end: end, name: name, values: values);
  }

  List<Node> _readAttributeValue() {
    String? quoteMark = read('"') ?? read("'");

    if (quoteMark != null && scan(quoteMark)) {
      return <Node>[Text(start: position - 1, end: position - 1)];
    }

    List<Node> value;

    try {
      Pattern end = quoteMark ?? _startsWithInvalidAttributeValue;
      value = _readSequence(end, 'in attribute value');
    } on ParseError catch (parserError) {
      if (parserError.errorCode.code == 'parse-error') {
        var SourceSpan(
          start: SourceLocation(offset: start),
          end: SourceLocation(offset: end),
        ) = parserError.span;

        if (string.substring(start, end) == '/>') {
          error(unclosedAttributeValue(quoteMark ?? '}'));
        }
      }

      rethrow;
    }

    if (value.isEmpty && quoteMark == null) {
      error(missingAttributeValue);
    }

    if (quoteMark != null) {
      expect(quoteMark);
    }

    return value;
  }

  List<Node> _readSequence(Pattern end, String location) {
    int start = position;
    List<Node> chunks = <Node>[];

    void flush(int end) {
      if (start < end) {
        String raw = string.substring(start, end);
        String data = decodeCharacterReferences(raw, true);
        chunks.add(Text(start: start, end: end, raw: raw, data: data));
        start = end;
      }
    }

    while (isNotDone) {
      if (match(end)) {
        flush(position);
        return chunks;
      }

      if (scan('{')) {
        if (match('#')) {
          int start = position - 1;
          skip('#');

          String name = readUntil(_nonCharRe);
          error(invalidLogicBlockPlacement(location, name), start);
        } else if (match('@')) {
          int start = position - 1;
          skip('#');

          String name = readUntil(_nonCharRe);
          error(invalidTagPlacement(location, name), start);
        }

        flush(position - 1);
        allowSpace();

        Expression expression = readExpression(closingCurlyRe);
        allowSpace();
        expect('}');

        MustacheTag mustacheTag = MustacheTag(
          start: start,
          end: position,
          expression: expression,
        );

        chunks.add(mustacheTag);

        start = position;
      } else {
        position += 1;
      }
    }

    error(unexpectedEOF);
  }

  void tag(int start) {
    if (scan('!--')) {
      String? data = readUntil('-->');
      expect('-->', unclosedComment);

      CommentTag commentTag = CommentTag(
        start: start,
        end: position,
        data: data,
        ignores: extractSvelteIgnore(data),
      );

      current.children.add(commentTag);
      return;
    }

    Node parent = current;
    bool isClosingTag = scan('/');
    String name = _readTagName();
    Tag element;

    String? metaTag = _metaTags[name];

    if (metaTag != null) {
      String slug = metaTag.toLowerCase();

      if (isClosingTag) {
        if ((name == 'svelte:window' || name == 'svelte:body') &&
            current.children.isNotEmpty) {
          error(invalidElementContent(slug, name), current.children[0].start);
        }
      } else {
        if (metaTags.contains(name)) {
          error(duplicateElement(slug, name), start);
        }

        if (stack.length > 1) {
          error(invalidElementPlacement(slug, name), start);
        }

        metaTags.add(name);
      }

      if (metaTag == 'Head') {
        element = Head(
          start: start,
          name: name,
          attributes: <Node>[],
          children: <Node>[],
        );
      } else if (metaTag == 'Options') {
        element = Options(
          start: start,
          name: name,
          attributes: <Node>[],
          children: <Node>[],
        );
      } else if (metaTag == 'Window') {
        element = Window(
          start: start,
          name: name,
          attributes: <Node>[],
          children: <Node>[],
        );
      } else if (metaTag == 'Document') {
        element = Document(
          start: start,
          name: name,
          attributes: <Node>[],
          children: <Node>[],
        );
      } else if (metaTag == 'Body') {
        element = Body(
          start: start,
          name: name,
          attributes: <Node>[],
          children: <Node>[],
        );
      } else {
        throw UnimplementedError(metaTag);
      }
    } else if (_capitalLetter.hasMatch(name) ||
        name == 'svelte:self' ||
        name == 'svelte:component') {
      element = InlineComponent(
        start: start,
        name: name,
        attributes: <Node>[],
        children: <Node>[],
      );
    } else if (name == 'svelte:element') {
      element = InlineElement(
        start: start,
        name: name,
        attributes: <Node>[],
        children: <Node>[],
      );
    } else if (name == 'svelte:fragment') {
      element = SlotTemplate(
        start: start,
        name: name,
        attributes: <Node>[],
        children: <Node>[],
      );
    } else if (name == 'title' && _parentIsHead(stack)) {
      element = Title(
        start: start,
        name: name,
        attributes: <Node>[],
        children: <Node>[],
      );
    } else if (name == 'slot') {
      element = Slot(
        start: start,
        name: name,
        attributes: <Node>[],
        children: <Node>[],
      );
    } else {
      element = Element(
        start: start,
        name: name,
        attributes: <Node>[],
        children: <Node>[],
      );
    }

    allowSpace();

    if (isClosingTag) {
      if (isVoid(name)) {
        error(invalidVoidContent(name), start);
      }

      expect('>');

      AutoCloseTag? tag = lastAutoCloseTag;

      while (parent is! Tag || parent.name != name) {
        if (parent is! Element) {
          if (tag != null && tag.tag == name) {
            error(invalidClosingTagAutoClosed(name, tag.reason), start);
          } else {
            error(invalidClosingTagUnopened(name), start);
          }
        }

        parent.end = start;
        stack.removeLast();
        parent = current;
      }

      parent.end = position;
      stack.removeLast();

      if (tag != null && tag.depth > stack.length) {
        lastAutoCloseTag = null;
      }

      return;
    }

    if (parent is HasName && closingTagOmitted(parent.name, name)) {
      parent.end = start;
      stack.removeLast();
      lastAutoCloseTag = (tag: parent.name, reason: name, depth: stack.length);
    }

    Set<String> uniqueNames = <String>{};

    while (true) {
      Node? attribute = _readAttribute(uniqueNames);

      if (attribute == null) {
        break;
      }

      element.attributes.add(attribute);
      allowSpace();
    }

    if (element is InlineComponent && name == 'svelte:component') {
      List<Node> attributes = element.attributes;
      Attribute? definition;

      for (int i = 0; i < attributes.length; i++) {
        Node attribute = attributes[i];

        if (attribute is Attribute && attribute.name == 'this') {
          definition = attribute;
          attributes.removeAt(i);
          break;
        }
      }

      if (definition == null) {
        error(missingComponentDefinition, start);
      }

      List<Node> values = definition.values;
      Expression? expression;

      found:
      {
        if (values.length == 1) {
          Node value = values.first;

          if (value is MustacheTag) {
            expression = value.expression;
            break found;
          }
        }

        error(invalidComponentDefinition, definition.start);
      }

      element.expression = expression;
    }

    if (element is InlineElement) {
      List<Node> attributes = element.attributes;
      Attribute? definition;

      for (int i = 0; i < attributes.length; i++) {
        Node attribute = attributes[i];

        if (attribute is Attribute && attribute.name == 'this') {
          definition = attribute;
          attributes.removeAt(i);
          break;
        }
      }

      if (definition == null) {
        error(missingElementDefinition, start);
      }

      if (definition.values.length != 1) {
        error(invalidElementDefinition, definition.start);
      }

      element.tag = definition.values.first;
    }

    if (stack.length == 1) {
      if (name == 'script') {
        readScript(start, element.attributes);
        return;
      }

      if (name == 'style') {
        readStyle(start, element.attributes);
        return;
      }
    }

    current.children.add(element);

    bool selfClosing = scan('/') || isVoid(name);
    expect('>');

    if (selfClosing) {
      element.end = position;
    } else if (name == 'textarea') {
      element.children = _readSequence(_textareaCloseTag, 'inside <textarea>');
      expect(_textareaCloseTag);
      element.end = position;
    } else if (name == 'script' || name == 'style') {
      int start = position;
      String closeTag = '</$name>';
      String data = readUntil(closeTag);
      element.children.add(Text(start: start, end: position, data: data));
      expect(closeTag);
      element.end = position;
    } else {
      stack.add(element);
    }
  }
}
