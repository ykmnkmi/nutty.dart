import 'dart:html';

import 'package:meta/dart2js.dart';
import 'package:svelte/src/runtime/fragment.dart';
import 'package:svelte/src/runtime/lifecycle.dart';
import 'package:svelte/src/runtime/scheduler.dart';
import 'package:svelte/src/runtime/state.dart';
import 'package:svelte/src/runtime/transition.dart';
import 'package:svelte/src/runtime/utilities.dart';

typedef Invalidate = void Function(int i, Object? value);

typedef Props = Map<String, Object?>;

typedef InstanceFactory = List<Object?> Function(
  Component component,
  Props props,
  Invalidate invalidate,
);

// TODO(runtime): replace with records
class Options {
  const Options({
    this.target,
    this.anchor,
    this.props,
    this.hydrate = false,
    this.intro = false,
  });

  final Element? target;

  final Node? anchor;

  final Props? props;

  final bool hydrate;

  final bool intro;
}

abstract class Component {
  final State _state = State();

  void Function(Props props)? _set;

  void set([Props? props]) {
    var set = _set;

    if (set != null && props != null && props.isNotEmpty) {
      set(props);
    }
  }

  bool _destroyed = false;

  bool get isDestroyed {
    return _destroyed;
  }

  void destroy() {
    if (_destroyed) {
      return;
    }

    destroyComponent(this, true);
    _destroyed = true;
  }
}

@tryInline
void setComponentUpdate(
  Component component,
  void Function() Function(List<int> dirty) updateFactory,
) {
  component._state.update = updateFactory(component._state.dirty);
}

@tryInline
void setComponentSet(
  Component component,
  void Function(Props props) setter,
) {
  component._set = setter;
}

@noInline
void init({
  required Component component,
  required Options options,
  InstanceFactory? createInstance,
  Fragment Function(List<Object?> instance)? createFragment,
  required Map<String, int> props,
  void Function(Element? target)? appendStyles,
  List<int>? dirty,
}) {
  var parentComponent = currentComponent;
  setCurrentComponent(component);

  var target = options.target;

  var state = component._state
    ..fragment = null
    ..instance = <Object?>[]
    ..props = props
    ..update = noop
    ..dirty = dirty ?? <int>[-1]
    ..root = target ?? parentComponent?._state.root;

  if (appendStyles != null) {
    appendStyles(target);
  }

  var ready = false;

  if (createInstance != null) {
    void invalidate(int i, Object? value) {
      if (state.instance[i] != (state.instance[i] = value)) {
        if (ready) {
          makeComponentDirty(component, i);
        }
      }
    }

    state.instance = createInstance(
      component,
      options.props ?? <String, Object?>{},
      invalidate,
    );
  }

  state.update();
  ready = true;

  if (createFragment != null) {
    state.fragment = createFragment(state.instance);
  }

  if (target != null) {
    if (options.hydrate) {
      // ...
    } else {
      state.fragment?.create();
    }

    if (options.intro) {
      // ...
    }

    mountComponent(component, target, options.anchor);
    flush();
  }

  setCurrentComponent(parentComponent);
}

@noInline
void createComponent(Component component) {
  component._state.fragment?.create();
}

@noInline
void mountComponent(Component component, Element target, [Node? anchor]) {
  component._state.fragment?.mount(target, anchor);
}

@noInline
void makeComponentDirty(Component component, int i) {
  var dirty = component._state.dirty;
  var index = i ~/ 31;

  if (dirty[0] == -1) {
    dirtyComponents.add(component);
    scheduleUpdate();
    dirty.fillRange(0, index + 1, 0);
  }

  dirty[index] |= 1 << i % 31;
}

@noInline
void updateComponent(Component component) {
  var state = component._state;
  state.update();

  var fragment = state.fragment;

  if (fragment != null) {
    var dirty = state.dirty;
    state.dirty[0] = -1;
    fragment.update(dirty);
  }
}

@tryInline
void transitionInComponent(Component component, bool local) {
  transitionIn(component._state.fragment, local);
}

@tryInline
void transitionOutComponent(
  Component component,
  bool local, [
  void Function()? callback,
]) {
  transitionOut(component._state.fragment, local, callback);
}

@noInline
void destroyComponent(Component component, bool detaching) {
  component._state
    ..fragment?.detach(detaching)
    ..fragment = null
    ..instance = <Object?>[];
}
