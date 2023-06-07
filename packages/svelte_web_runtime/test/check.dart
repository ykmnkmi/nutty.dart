// NgSvelte
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:html' show Element, Text;

import 'package:stack_trace/stack_trace.dart' show Trace;
import 'package:svelte_web_runtime/src/dom.dart'
    show
        append,
        detach,
        element,
        insert,
        listen,
        listener,
        setData,
        space,
        text;
import 'package:svelte_web_runtime/src/fragment.dart' show Fragment;

// API

final class Input {
  const Input([this.name]);

  final String? name;
}

abstract interface class OnMount {
  void onMount();
}

abstract interface class OnDestroy {
  void onDestroy();
}

abstract class Component<T extends Object> {
  T get context;

  List<Object?> get instance;

  Fragment? get fragment;

  int dirty = -1;

  void makeDirty(int index) {
    if (dirty == -1) {
      dirtyComponents.add(this);
      scheduleUpdate();
      dirty = 0;
    }

    dirty |= 1 << index % 31;
  }

  void invalidate(int index, Object? value, [Object? expression]) {
    if (instance[index] != (instance[index] = value) || expression != null) {
      makeDirty(index);
    }
  }
}

void runApp<T extends Object>(Component<T> Function() componentFactory) {
  var component = componentFactory();
  var fragment = component.fragment;
  fragment?.create();
}

List<Component> dirtyComponents = <Component>[];

void scheduleUpdate() {}

// USER CODE

class App implements OnMount, OnDestroy {
  int count = 0;

  late int doubled = count * 2;

  late int quadrupled = doubled * 2;

  void handleClick() {
    count += 1;
  }

  late Timer timer;

  @override
  void onMount() {
    timer = Timer.periodic(Duration(seconds: 2), (timer) {
      count += 1;
    });
  }

  @override
  void onDestroy() {
    timer.cancel();
  }
}

void main() {
  try {
    runApp<App>(appFactory);
  } catch (error, stackTrace) {
    print(error);
    print(Trace.format(stackTrace));
  }
}

// GENERATED

Fragment createFragment(List<Object?> instance) {
  late Element button;
  late Text t0, t1, t2;
  late Element p0;
  late Text t3, t4, t5, t6;
  late Element p1;
  late Text t7, t8, t9;

  var mounted = false;

  late void Function() dispose;

  return Fragment(
    create: () {
      button = element('button');
      t0 = text('Count: ');
      t1 = text('${instance.count}');
      t2 = space();
      p0 = element('p');
      t3 = text('${instance.count}');
      t4 = text(' * 2 = ');
      t5 = text('${instance.doubled}');
      t6 = space();
      p1 = element('p');
      t7 = text('${instance.doubled}');
      t8 = text(' * 2 = ');
      t9 = text('${instance.quadrupled}');
    },
    mount: (target, anchor) {
      insert(target, button, anchor);
      append(button, t0);
      append(button, t1);
      insert(target, t2, anchor);
      insert(target, p0, anchor);
      append(p0, t3);
      append(p0, t4);
      append(p0, t5);
      insert(target, t6, anchor);
      insert(target, p1, anchor);
      append(p1, t7);
      append(p1, t8);
      append(p1, t9);

      if (!mounted) {
        dispose = listen(button, 'click', listener(instance.handleClick));
        mounted = true;
      }
    },
    update: (context, dirty) {
      if (dirty & 1 != 0) {
        setData(t1, '${context.count}');
        setData(t3, '${context.count}');
      }

      if (dirty & 2 != 0) {
        setData(t5, '${context.doubled}');
        setData(t7, '${context.doubled}');
      }

      if (dirty & 4 != 0) {
        setData(t9, '${context.quadrupled}');
      }
    },
    detach: (detaching) {
      if (detaching) {
        detach(button);
        detach(t2);
        detach(p0);
        detach(t6);
        detach(p1);
      }

      mounted = false;
      dispose();
    },
  );
}

extension AppInstance on List<Object?> {
  int get count {
    return this[0] as int;
  }

  int get doubled {
    return this[1] as int;
  }

  int get quadrupled {
    return this[2] as int;
  }

  void Function() get handleClick {
    return this[3] as void Function();
  }
}

class AppContext extends App {
  AppContext(this._component);

  final AppComponent _component;

  @override
  set count(int count) {
    _component.invalidate(0, super.count = count);
  }

  @override
  set doubled(int doubled) {
    _component.invalidate(1, super.doubled = doubled);
  }

  @override
  set quadrupled(int quadrupled) {
    _component.invalidate(2, super.quadrupled = quadrupled);
  }

  List<Object?> get _instance {
    return <Object?>[count, doubled, quadrupled, handleClick];
  }
}

class AppComponent extends Component<App> {
  @override
  late final AppContext context = AppContext(this);

  @override
  late final List<Object?> instance = context._instance;

  @override
  late final Fragment fragment = createFragment(instance);
}

Component<App> appFactory() {
  return AppComponent();
}