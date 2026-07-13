import 'package:flutter/services.dart';

Future<bool> copyText(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  return true;
}
