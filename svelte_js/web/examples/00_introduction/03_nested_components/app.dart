import 'dart:js_interop';

import 'package:svelte_js/internal.dart' as $; // ignore: library_prefixes
import 'package:svelte_js/svelte_js.dart';
import 'package:web/web.dart';

import 'nested.dart';

extension type AppProperties._(JSObject object) implements JSObject {
  AppProperties() : object = JSObject();
}

extension type const App._(Component<AppProperties> component) {
  void call(Node node) {
    component(node, AppProperties());
  }
}

const App app = App._(_component);

final _fragment =
    $.fragment('<p class="svelte-urs9w7">These styles...</p> <!>');

void _component(Node $anchor, AppProperties $properties) {
  $.push($properties, false);
  $.init();

  /* Init */
  var fragment = $.openFragment($anchor, true, _fragment);
  var p = $.childFragment<Element>(fragment);
  var node = $.sibling<Node>($.sibling<Node>(p));

  nested(node);
  $.closeFragment($anchor, fragment);
  $.pop();
}
