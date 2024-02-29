import 'dart:js_interop';

import 'package:svelte_js/internal.dart' as $; // ignore: library_prefixes
import 'package:svelte_js/svelte_js.dart';
import 'package:web/web.dart';

extension type NestedProperties._(JSObject object) implements JSObject {
  NestedProperties() : object = JSObject();
}

extension type const Nested._(Component<NestedProperties> component) {
  void call(Node node) {
    component(node, NestedProperties());
  }
}

const Nested nested = Nested._(_component);

final _template = $.template("<p>...don't affect this element</p>");

void _component(Node $anchor, NestedProperties $properties) {
  $.push($properties, false);
  $.init();

  /* Init */
  var p = $.open<Element>($anchor, true, _template);

  $.close($anchor, p);
  $.pop();
}
