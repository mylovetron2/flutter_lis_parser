// CodeReader service - converted from C++ ReadCode functions

import 'dart:typed_data';
import '../constants/lis_constants.dart';

class CodeReader {
  static double readCode(Uint8List entry, int reprCode, int size) {
    switch (reprCode) {
      case 56: // Signed byte
        return _readSignedByte(entry);
      case 65: // Character string - returns depth unit constant
        return _readDepthUnit(entry, size);
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
    String unit = String.fromCharCodes(chars).trim();

    switch (unit) {
      case 'CM':
        return LisConstants.depthUnitCm.toDouble();
      case '.5MM':
        return LisConstants.depthUnitHmm.toDouble();
      case 'MM':
        return LisConstants.depthUnitMm.toDouble();
      case 'M':
        return LisConstants.depthUnitM.toDouble();
      case '.1IN':
        return LisConstants.depthUnitP1in.toDouble();
      default:
        return LisConstants.depthUnitUnknown.toDouble();
    }
  }

  static double _read32BitFloat(Uint8List entry) {
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
      int exponentBits = (result & 0x7f800000) >> 23;
      double exponent;
      if (exponentBits <= 127) {
        exponent = 1.0;
        for (int i = 0; i < 127 - exponentBits; i++) {
          exponent *= 2.0;
        }
      } else {
        exponent = 1.0;
        for (int i = 0; i < exponentBits - 127; i++) {
          exponent /= 2.0;
        }
      }

      int fractionBits = result & 0x7fffff;
      fractionBits = ~fractionBits;
      fractionBits = fractionBits + 1;
      fractionBits = fractionBits << 9;

      double fraction = 0.0;
      double factor = 0.5;
      while (fractionBits > 0) {
        if ((fractionBits & 0x80000000) != 0) {
          fraction += factor;
        }
        factor /= 2;
        fractionBits = fractionBits << 1;
      }

      return -1.0 * fraction * exponent;
    } else {
      // Positive number
      int exponentBits = (result & 0x7f800000) >> 23;
      double exponent;
      if (exponentBits >= 128) {
        exponent = 1.0;
        for (int i = 0; i < exponentBits - 128; i++) {
          exponent *= 2.0;
        }
      } else {
        exponent = 1.0;
        for (int i = 0; i < 128 - exponentBits; i++) {
          exponent /= 2.0;
        }
      }

      int fractionBits = result & 0x7fffff;
      fractionBits = fractionBits << 9;

      double fraction = 0.0;
      double factor = 0.5;
      while (fractionBits > 0) {
        if ((fractionBits & 0x80000000) != 0) {
          fraction += factor;
        }
        factor /= 2;
        fractionBits = fractionBits << 1;
      }

      return fraction * exponent;
    }
  }

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
    if (entry[0] > 128) {
      int temp = entry[0];
      temp <<= 8;
      temp += entry[1];
      temp = ~temp;
      temp += 1;
      return (-1 * temp).toDouble();
    } else {
      return (entry[0] * 256 + entry[1]).toDouble();
    }
  }
}
