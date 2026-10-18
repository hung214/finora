import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// 台灣電子發票右側 QR 明細編碼（SDD §5.4）：**deflate（raw）＋ Base32（字元集 0-9A-Z）**。
///
/// 規格由財政部訂定；本編碼器同時用於測資產生（T-H6 fixtures）與解析回程，
/// 規格變動 → 版本化調整並以金測樣本回歸（SDD R6）。
class InvoiceDetailCodec {
  InvoiceDetailCodec._();

  static const String _alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  static String encode(String text) =>
      base32Encode(Uint8List.fromList(ZLibEncoder(raw: true).convert(utf8.encode(text))));

  static String decode(String encoded) =>
      utf8.decode(ZLibDecoder(raw: true).convert(base32Decode(encoded)));

  /// Base32（0-9A-Z，無 padding）：5 bits 一組，尾端補零湊滿。
  static String base32Encode(List<int> bytes) {
    var buffer = 0;
    var bits = 0;
    final out = StringBuffer();
    for (final b in bytes) {
      buffer = (buffer << 8) | (b & 0xFF);
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        out.write(_alphabet[(buffer >> bits) & 0x1F]);
      }
    }
    if (bits > 0) {
      out.write(_alphabet[(buffer << (5 - bits)) & 0x1F]);
    }
    return out.toString();
  }

  static List<int> base32Decode(String s) {
    final clean = s.replaceAll('=', '');
    var buffer = 0;
    var bits = 0;
    final out = <int>[];
    for (final ch in clean.runes) {
      final v = _alphabet.indexOf(String.fromCharCode(ch));
      if (v < 0) {
        throw FormatException('Base32 字元集外: ${String.fromCharCode(ch)}');
      }
      buffer = (buffer << 5) | v;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.add((buffer >> bits) & 0xFF);
      }
    }
    return out;
  }
}
