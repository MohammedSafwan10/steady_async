import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> copyText(String text) async {
  if (web.window.isSecureContext) {
    try {
      await web.window.navigator.clipboard.writeText(text).toDart;
      return true;
    } catch (_) {
      // Fall through for browsers that expose the API but deny access.
    }
  }

  final body = web.document.body;
  if (body == null) return false;
  final textArea =
      web.document.createElement('textarea') as web.HTMLTextAreaElement;
  textArea.value = text;
  textArea.setAttribute('readonly', '');
  textArea.style.position = 'fixed';
  textArea.style.opacity = '0';
  textArea.style.pointerEvents = 'none';
  body.append(textArea);
  textArea.select();
  final copied = web.document.execCommand('copy');
  textArea.remove();
  return copied;
}
