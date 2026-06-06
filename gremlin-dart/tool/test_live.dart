import 'dart:typed_data';

import 'package:gremlin_dart/process/traversal.dart';

import '../lib/driver/connection.dart';
import '../lib/driver/request_message.dart';
import '../lib/structure/graph.dart';
import '../lib/structure/io/graph_binary/graph_binary_writer.dart';

void main() async {
  _printRequestHexDiagnostics();

  // Bindings: simple int param
  await _test('bind int', 'g.V(vid)', 'gmodern', bindings: {'vid': 1});
  await _test('bind GInt', 'g.V(vid)', 'gmodern', bindings: {'vid': GInt(1)});
  await _test('bind string', 'g.V().has("name", n)', 'gmodern',
      bindings: {'n': 'marko'});
  await _test('bind vertex', 'g.V(vid)', 'gmodern',
      bindings: {'vid': Vertex('1', 'person')});

  // Sack
  await _test('sack with 0.5f',
      'g.withSack(2147483647i).inject(0.5f).sack(div).sack()', 'gmodern');
  await _test('sack with 0.5D',
      'g.withSack(2147483647i).inject(0.5D).sack(div).sack()', 'gmodern');
  await _test('sack with 0.5',
      'g.withSack(2147483647i).inject(0.5).sack(div).sack()', 'gmodern');

  // Conjoin: list vs separate args
  await _test(
      'conjoin [null,null]', 'g.inject([null,null]).conjoin("+")', 'ggraph');
  await _test(
      'conjoin null,null', 'g.inject(null, null).conjoin("+")', 'ggraph');
}

Future<void> _test(String name, String gremlin, String g,
    {Map<String, dynamic>? bindings}) async {
  final builder = RequestMessage.build(gremlin).addG(g).addBulkResults(true);
  if (bindings != null) builder.addBindings(bindings);
  final req = builder.create();
  final c = Connection('http://localhost:45940/gremlin');
  try {
    final rs = await c.submit(req);
    print('[$name] → ${rs.items}');
  } catch (e) {
    print('[$name] ERROR: $e');
  } finally {
    await c.close();
  }
}

void _printRequestHexDiagnostics() {
  _dumpRequestBytes(
    'without bindings',
    RequestMessage.build('g.V()').addG('gmodern').addBulkResults(true).create(),
  );
  _dumpRequestBytes(
    'with bindings',
    RequestMessage.build('g.V(vid)')
        .addG('gmodern')
        .addBulkResults(true)
        .addBindings({'vid': 1}).create(),
  );
}

void _dumpRequestBytes(String name, RequestMessage request) {
  final bytes = GraphBinaryWriter().writeRequest(request);
  print('[$name request bytes] ${bytes.length} bytes');
  print(_hexDump(bytes));
}

String _hexDump(Uint8List bytes, {int width = 16}) {
  final buffer = StringBuffer();
  for (var offset = 0; offset < bytes.length; offset += width) {
    final end = offset + width > bytes.length ? bytes.length : offset + width;
    final chunk = bytes.sublist(offset, end);
    final hex = chunk
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join(' ')
        .padRight(width * 3 - 1);
    final ascii = chunk
        .map((byte) =>
            byte >= 0x20 && byte <= 0x7e ? String.fromCharCode(byte) : '.')
        .join();
    buffer.writeln('${offset.toRadixString(16).padLeft(4, '0')}  $hex  $ascii');
  }
  return buffer.toString();
}
