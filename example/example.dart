import 'dart:convert' show JsonEncoder;

import 'package:piko/compiler.dart';
import 'package:stack_trace/stack_trace.dart' show Trace;

const String helloWorld = '''
<script>
	var name = 'world';
</script>

<h1>Hello {name}!</h1>''';

void main() {
  try {
    print(JsonEncoder.withIndent('  ').convert(parse(helloWorld).toJson(printData: true)));
  } catch (error, trace) {
    print(error);
    print(Trace.format(trace, terse: true));
  }
}

// ignore_for_file: avoid_print
