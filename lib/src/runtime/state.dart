import 'dart:html';

import 'package:svelte/src/runtime/fragment.dart';

class State {
  Fragment? fragment;

  late List<Object?> instance;

  late Map<String, int> props;

  late void Function() update;

  late List<int> dirty;

  Element? root;
}
