// CodeReader service - converted from C++ ReadCode functions

import 'dart:math' as math;
import 'dart:typed_data';

import '../constants/lis_constants.dart';

class CodeReader {
  /// Giải mã 4 byte kiểu float LIS về double
  static double decode32BitFloat(Uint8List entry) {
    int byte1 = entry[0];
    int byte2 = entry[1];
    int byte3 = entry[2];
    int byte4 = entry[3];

    int ePart = ((byte1 << 1) & 0xFF) + (byte2 >= 128 ? 1 : 0);
    int mPart = ((byte2 << 16) | (byte3 << 8) | byte4) & 0x7FFFFF;

    double M = 0;
    List<double> factor = [
      0,
      0.5,
      0.25,
      0.125,
      0.0625,
      0.03125,
      0.015625,
      0.0078125,
      0.00390625,
      0.001953125,
      0.0009765625,
      0.00048828125,
      0.000244140625,
      0.0001220703125,
      0.00006103515625,
      0.000030517578125,
      0.0000152587890625,
      0.00000762939453125,
      0.000003814697265625,
      0.0000019073486328125,
      0.00000095367431640625,
      0.000000476837158203125,
      0.0000002384185791015625,
      0.00000011920928955078125,
    ];

    if (byte1 >= 128) {
      mPart = (~mPart + 1) & 0x7FFFFF;
    }

    int E = ePart;
    int mPart2 = mPart << 8;
    for (int i = 0; i < 24; i++) {
      if ((mPart2 & 0x80000000) == 0x80000000) M += factor[i];
      mPart2 = mPart2 << 1;
    }

    double value;
    if (byte1 < 128) {
      value = M * math.pow(2.0, E - 128);
    } else {
      value = (M.abs() < 0.00000001) ? 0 : -M * math.pow(2.0, 127 - E);
    }

    return value;
  }

  static dynamic readCode(Uint8List entry, int reprCode, int size) {
    switch (reprCode) {
      case 56: // Signed byte
        return _readSignedByte(entry);
      case 65: // Character string - trả về chuỗi gốc
        return String.fromCharCodes(entry.sublist(0, size)).trim();
      case 66: // Unsigned byte
        return entry[0].toDouble();
      case 68: // 32-bit float
        return _read32BitFloat(entry);
      case 73: // 32-bit integer
        return _read32BitInteger(entry);
      case 79: // 16-bit integer
        return _read16BitInteger(entry);
      default:
        throw Exception('Unknown representation code: $reprCode');
    }
  }

  static int getCodeSize(int code) {
    switch (code) {
      case 49:
        return 2;
      case 50:
        return 4;
      case 56:
        return 1;
      case 66:
        return 1;
      case 68:
        return 4;
      case 70:
        return 4;
      case 73:
        return 4;
      case 79:
        return 2;
      default:
        throw Exception('Unknown code size for code: $code');
    }
  }

  static int getCodeType(int code) {
    switch (code) {
      case 49:
      case 50:
      case 68:
      case 70:
        return LisConstants.typeFloat;
      case 56:
      case 66:
      case 73:
      case 79:
        return LisConstants.typeInt;
      case 65:
        return LisConstants.typeChar;
      default:
        return LisConstants.typeUnknown;
    }
  }

  static double _readSignedByte(Uint8List entry) {
    int ch = entry[0];
    if (ch < 128) {
      return ch.toDouble();
    } else {
      int result = ch;
      result = ~result;
      result = result + 1;
      return (-1 * result).toDouble();
    }
  }

  static double _readDepthUnit(Uint8List entry, int size) {
    final chars = List.generate(size, (i) => entry[i]);
    String unit = String.fromCharCodes(chars).trim().toUpperCase();

    // Accept a few common variants used in LIS headers
    switch (unit) {
      case 'CM':
      case 'CMS':
        return LisConstants.depthUnitCm.toDouble();
      case '.5MM':
      case '0.5MM':
        return LisConstants.depthUnitHmm.toDouble();
      case 'MM':
      case 'MMS':
        return LisConstants.depthUnitMm.toDouble();
      case 'M':
      case 'METRE':
      case 'METERS':
      case 'METRE(S)':
        return LisConstants.depthUnitM.toDouble();
      case 'FT':
      case 'FEET':
      case "'":
        return LisConstants.depthUnitFeet.toDouble();
      case '.1IN':
      case '0.1IN':
        return LisConstants.depthUnitP1in.toDouble();
      default:
        return LisConstants.depthUnitUnknown.toDouble();
    }
  }

  static double _read32BitFloat(Uint8List entry) {
    int byte1 = entry[0];
    int byte2 = entry[1];
    int byte3 = entry[2];
    int byte4 = entry[3];

    int ePart = ((byte1 << 1) & 0xFF) + (byte2 >= 128 ? 1 : 0);
    int mPart = ((byte2 << 16) | (byte3 << 8) | byte4) & 0x7FFFFF;

    double M = 0;
    List<double> factor = [
      0,
      0.5,
      0.25,
      0.125,
      0.0625,
      0.03125,
      0.015625,
      0.0078125,
      0.00390625,
      0.001953125,
      0.0009765625,
      0.00048828125,
      0.000244140625,
      0.0001220703125,
      0.00006103515625,
      0.000030517578125,
      0.0000152587890625,
      0.00000762939453125,
      0.000003814697265625,
      0.0000019073486328125,
      0.00000095367431640625,
      0.000000476837158203125,
      0.0000002384185791015625,
      0.00000011920928955078125,
    ];

    if (byte1 >= 128) {
      mPart = (~mPart + 1) & 0x7FFFFF;
    }

    int E = ePart;
    int mPart2 = mPart << 8;
    for (int i = 0; i < 24; i++) {
      if ((mPart2 & 0x80000000) == 0x80000000) M += factor[i];
      mPart2 = mPart2 << 1;
    }

    double value;
    if (byte1 < 128) {
      value = M * math.pow(2.0, E - 128);
    } else {
      value = (M.abs() < 0.00000001) ? 0 : -M * math.pow(2.0, 127 - E);
    }

    return value;
  }

  /// Mã hóa số thực thành 4 byte kiểu float LIS (big endian)

  static double _read32BitInteger(Uint8List entry) {
    int ch0 = entry[0];
    int ch1 = entry[1];
    int ch2 = entry[2];
    int ch3 = entry[3];

    int result = 0;
    result |= (ch0 << 24);
    result |= (ch1 << 16);
    result |= (ch2 << 8);
    result |= ch3;

    if (ch0 >= 128) {
      // Negative number
      result = ~result;
      result = result + 1;
      return (-1 * result).toDouble();
    }

    return result.toDouble();
  }

  static double _read16BitInteger(Uint8List entry) {
    // Read as big-endian 16-bit value
    int value = (entry[0] << 8) | entry[1];

    // Check if this is a negative value (MSB set)
    if (value >= 0x8000) {
      // Convert from two's complement to negative
      value = value - 0x10000;
    }

    return value.toDouble();
  }

  /// Mã hóa giá trị thành Uint8List cho từng reprCode
  static Uint8List encodeSignedByte(dynamic value) {
    int v = value is num ? value.toInt() : 0;
    return Uint8List.fromList([v & 0xFF]);
  }

  static Uint8List encodeAscii(dynamic value, int size) {
    String str = value?.toString() ?? '';
    List<int> bytes = str.padRight(size).codeUnits;
    return Uint8List.fromList(bytes.take(size).toList());
  }

  static Uint8List encodeUnsignedByte(dynamic value) {
    int v = value is num ? value.toInt() : 0;
    return Uint8List.fromList([v & 0xFF]);
  }

  // static Uint8List encode32BitFloat(dynamic value) {
  //   double v = value is num ? value.toDouble() : 0.0;
  //   return CodeReader.encode32BitFloat(v);
  // }
  static Uint8List encode32BitFloat(double value) {
    if (value == 0.0) return Uint8List.fromList([0, 0, 0, 0]);
    bool isNegative = value < 0;
    double absValue = value.abs();
    // Đầu tiên thử encode đặc biệt như cũ
    int E = 0;
    double M = 0;
    for (int e = 127; e >= 0; e--) {
      double v = 0.5 * math.pow(2.0, 127 - e);
      if ((absValue - v).abs() < 0.0001) {
        E = e;
        M = 0.5;
        break;
      }
    }
    if (M != 0) {
      int byte1 = isNegative ? (E >> 1) | 0x80 : (E >> 1);
      int byte2 = ((E & 1) << 7) | 0x40;
      int byte3 = 0;
      int byte4 = 0;
      return Uint8List.fromList([byte1, byte2, byte3, byte4]);
    }
    // Nếu không phải giá trị đặc biệt, encode ngược lại từ logic decode32BitFloat
    // Tìm E và M phù hợp
    if (!isNegative) {
      // value = M * 2^(E - 128)
      double log2 = math.log(absValue) / math.ln2;
      E = (log2 + 128).floor();
      M = absValue / math.pow(2.0, E - 128);
    } else {
      // value = -M * 2^(127 - E)
      double log2 = math.log(absValue) / math.ln2;
      E = (127 - log2).floor();
      M = absValue / math.pow(2.0, 127 - E);
    }
    // Chuyển M thành mPart (giống decode)
    int mPart = 0;
    double remain = M;
    List<double> factor = [
      0,
      0.5,
      0.25,
      0.125,
      0.0625,
      0.03125,
      0.015625,
      0.0078125,
      0.00390625,
      0.001953125,
      0.0009765625,
      0.00048828125,
      0.000244140625,
      0.0001220703125,
      0.00006103515625,
      0.000030517578125,
      0.0000152587890625,
      0.00000762939453125,
      0.000003814697265625,
      0.0000019073486328125,
      0.00000095367431640625,
      0.000000476837158203125,
      0.0000002384185791015625,
      0.00000011920928955078125,
    ];
    for (int i = 1; i < factor.length; i++) {
      if (remain >= factor[i]) {
        mPart |= (1 << (23 - (i - 1)));
        remain -= factor[i];
      }
    }
    if (isNegative) {
      mPart = (~mPart + 1) & 0x7FFFFF;
    }
    int byte1 = isNegative ? (E >> 1) | 0x80 : (E >> 1);
    int byte2 = ((E & 1) << 7) | ((mPart >> 16) & 0x7F);
    int byte3 = (mPart >> 8) & 0xFF;
    int byte4 = mPart & 0xFF;
    return Uint8List.fromList([byte1, byte2, byte3, byte4]);
  }

  static Uint8List encode32BitInteger(dynamic value) {
    int v = value is num ? value.toInt() : 0;
    return Uint8List.fromList([
      (v >> 24) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 8) & 0xFF,
      v & 0xFF,
    ]);
  }

  static Uint8List encode16BitInteger(dynamic value) {
    int v = value is num ? value.toInt() : 0;
    return Uint8List.fromList([(v >> 8) & 0xFF, v & 0xFF]);
  }

  /// Hàm tổng hợp gọi từng hàm encode theo reprCode
  static Uint8List encode(dynamic value, int reprCode, int size) {
    switch (reprCode) {
      case 56:
        return encodeSignedByte(value);
      case 65:
        return encodeAscii(value, size);
      case 66:
        return encodeUnsignedByte(value);
      case 68:
        return encode32BitFloat(value);
      case 73:
        return encode32BitInteger(value);
      case 79:
        return encode16BitInteger(value);
      default:
        throw Exception('Unknown representation code for encode: $reprCode');
    }
  }
}
