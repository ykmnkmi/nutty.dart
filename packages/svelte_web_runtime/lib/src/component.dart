import 'dart:html';

import 'package:meta/dart2js.dart';
import 'package:svelte_web_runtime/src/fragment.dart';
import 'package:svelte_web_runtime/src/lifecycle.dart';
import 'package:svelte_web_runtime/src/scheduler.dart';
import 'package:svelte_web_runtime/src/state.dart';
import 'package:svelte_web_runtime/src/transition.dart';
import 'package:svelte_web_runtime/src/utilities.dart';

typedef Invalidate = void Function(int i, Object? value, [Object? expression]);

typedef InstanceFactory = List<Object?> Function(
  Component component,
  Map<String, Object?> props,
  Invalidate invalidate,
);

typedef Options = ({
  Element? target,
  Node? anchor,
  Map<String, Object?>? props,
  bool hydrate,
  bool intro,
});

abstract class Component {
  final State _state = State();

  void Function(Map<String, Object?> props)? _set;

  void set([Map<String, Object?>? props]) {
    var set = _set;

    if (set != null && props != null) {
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
  void Function() Function(int dirty) updateFactory,
) {
  component._state.update = updateFactory(component._state.dirty);
}

@tryInline
void setComponentSet(
  Component component,
  void Function(Map<String, Object?> props) setter,
) {
  component._set = setter;
}

@noInline
void init({
  required Component component,
  required Options options,
  InstanceFactory? createInstance,
  Fragment Function(List<Object?> instance)? createFragment,
  Map<String, int> props = const <String, int>{},
  void Function(Element? target)? appendStyles,
  int dirty = -1,
}) {
  var parentComponent = currentComponent;
  setCurrentComponent(component);

  var target = options.target;

  var state = component._state
    ..fragment = null
    ..instance = <Object?>[]
    ..props = props
    ..update = noop
    ..dirty = dirty
    ..root = target ?? parentComponent?._state.root;

  if (appendStyles != null) {
    appendStyles(target);
  }

  var ready = false;

  if (createInstance != null) {
    void invalidate(int i, Object? value, [Object? expression]) {
      if (state.instance[i] != (state.instance[i] = value) ||
          expression != null) {
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
      throw UnimplementedError();
    } else {
      state.fragment?.create();
    }

    if (options.intro) {
      transitionIn(state.fragment, false);
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
  if (component._state.dirty == -1) {
    dirtyComponents.add(component);
    scheduleUpdate();
    component._state.dirty = 0;
  }

  component._state.dirty |= 1 << i % 31;
}

@noInline
void updateComponent(Component component) {
  var state = component._state;
  state.update();

  var fragment = state.fragment;

  if (fragment != null) {
    var dirty = state.dirty;
    state.dirty = -1;
    fragment.update(state.instance, dirty);
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