import 'dart:convert';

import 'package:piko/compiler.dart';
import 'package:stack_trace/stack_trace.dart';

const JsonEncoder encoder = JsonEncoder.withIndent('  ');

const String template = '''
<Component test={{a: 1} />
''';

void main(List<String> arguments) {
  try {
    var ast = parse(template);
    print(encoder.convert(ast.toJson()));
  } on CompileError catch (error) {
    // print(error);
    // print(Trace.format(stackTrace));
    print(encoder.convert(error.toJson()));
  } catch (error, stackTrace) {
    print(error);
    print(Trace.format(stackTrace));
  }
}
