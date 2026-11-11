import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef _AnalyzeNative = Float Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _AnalyzeDart   = double Function(Pointer<Utf8>, Pointer<Utf8>);

class FfiBridge {
  late final DynamicLibrary _lib;
  late final _AnalyzeDart _analyze;

  FfiBridge() {
    if (Platform.isAndroid || Platform.isLinux) {
      _lib = DynamicLibrary.open('libneuromesh_core.so');
    } else if (Platform.isWindows) {
      _lib = DynamicLibrary.open('neuromesh_core.dll');
    } else {
      throw UnsupportedError('Platform not supported');
    }
    
    _analyze = _lib.lookupFunction<_AnalyzeNative, _AnalyzeDart>('analyze_asymmetry');
  }

  double audit(String newMsg, String original) {
    final a = newMsg.toNativeUtf8();
    final b = original.toNativeUtf8();
    try {
      return _analyze(a, b);
    } finally {
      malloc.free(a);
      malloc.free(b);
    }
  }
}