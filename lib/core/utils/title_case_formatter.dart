import 'package:flutter/services.dart';

/// A [TextInputFormatter] that capitalizes the first letter of each word.
class TitleCaseTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final text = newValue.text;
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      // Capitalize if it's the first character or if the previous character was a space
      if (i == 0 || text[i - 1] == ' ') {
        buffer.write(char.toUpperCase());
      } else {
        buffer.write(char);
      }
    }

    return newValue.copyWith(
      text: buffer.toString(),
      selection: newValue.selection,
    );
  }
}
