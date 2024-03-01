import 'dart:js_interop';

import 'package:svelte_js/internal.dart' as $; // ignore: library_prefixes
import 'package:svelte_js/svelte_js.dart';
import 'package:web/web.dart';

extension type AppProperties._(JSObject object) implements JSObject {
  AppProperties() : object = JSObject();
}

extension type const App._(Component<AppProperties> component) {
  void call(Node node) {
    component(node, AppProperties());
  }
}

const App app = App._(_component);

final _fragment = $.fragment('<button> </button> <p> </p> <p> </p>');

void _component(Node $anchor, AppProperties $properties) {
  $.push($properties, true);

  var count = $.mutableSource<int>(0);
  var doubled = $.mutableSource<int>();
  var quadrupled = $.mutableSource<int>();

  void handleClick(Event event) {
    $.set<int>(count, $.get<int>(count) + 1);
  }

  $.preEffect(() {
    $.get<int>(count);

    $.untrack<void>(() {
      $.set<int>(doubled, $.get<int>(count) * 2);
    });
  });

  $.preEffect(() {
    $.get<int>(doubled);

    $.untrack<void>(() {
      $.set<int>(quadrupled, $.get<int>(doubled) * 2);
    });
  });

  $.init();

  /* Init */
  var fragment = $.openFragment($anchor, true, _fragment);
  var button = $.childFragment<Element>(fragment);
  var text = $.child<Text>(button);
  var p = $.sibling<Element>($.sibling<Text>(button, true));
  var text1 = $.child<Text>(p);
  var p1 = $.sibling<Element>($.sibling<Text>(p, true));
  var text2 = $.child<Text>(p1);

  /* Update */
  $.renderEffect(() {
    $.text(text, 'Count: ${$.get<int>(count)}');
    $.text(text1, '${$.get<int>(count)} * 2 = ${$.get<int>(doubled)}');
    $.text(text2, '${$.get<int>(doubled)} * 2 = ${$.get<int>(quadrupled)}');
  });

  $.event('click', button, handleClick, false);
  $.closeFragment($anchor, fragment);
  $.pop();
}