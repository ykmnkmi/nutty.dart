import '../../interface.dart';
import '../parse.dart';
import '../read/expression.dart';

extension MustacheParser on Parser {
  void mustache() {
    expect('{');
    allowWhitespace();

    if (scan('/')) {
      throw UnimplementedError();
    } else if (scan(':else')) {
      throw UnimplementedError();
    } else if (match(':then') || match(':catch')) {
      throw UnimplementedError();
    } else if (scan('#')) {
      throw UnimplementedError();
    } else if (scan('@html')) {
      throw UnimplementedError();
    } else if (scan('@debug')) {
      throw UnimplementedError();
    } else {
      current.add(Mustache(readExpression()));
    }

    allowWhitespace();
    expect('}');
  }
}