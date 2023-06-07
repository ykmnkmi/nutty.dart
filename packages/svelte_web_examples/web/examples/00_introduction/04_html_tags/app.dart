import 'dart:html';

import 'package:svelte_web_runtime/svelte_web_runtime.dart';

Fragment createFragment(List<Object?> instance) {
  late Element p;

  return Fragment(
    create: () {
      p = element('p');
    },
    mount: (target, anchor) {
      insert(target, p, anchor);
      setInnerHtml(p, instance._string);
    },
    detach: (detaching) {
      if (detaching) {
        detach(p);
      }
    },
  );
}

List<Object?> createInstance(
  Component self,
  Map<String, Object?> props,
  Invalidate invalidate,
) {
  var string = "here's some <strong>HTML!!!</strong>";
  return <Object?>[string];
}

extension on List<Object?> {
  String get _string {
    return this[0] as String;
  }
}

class App extends Component {
  App({
    Element? target,
    Node? anchor,
    Map<String, Object?>? props,
    bool hydrate = false,
    bool intro = false,
  }) {
    init(
      component: this,
      options: (
        target: target,
        anchor: anchor,
        props: props,
        hydrate: hydrate,
        intro: intro,
      ),
      createInstance: createInstance,
      createFragment: createFragment,
    );
  }
}