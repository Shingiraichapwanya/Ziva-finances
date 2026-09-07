// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web implementation using window.location.hash
void setUrlAnchor(String anchor) {
  try {
    final cleanAnchor = anchor.startsWith('#') ? anchor : '#$anchor';
    html.window.location.hash = cleanAnchor;
  } catch (_) {}
}

String getUrlAnchor() {
  try {
    return html.window.location.hash;
  } catch (_) {
    return '';
  }
}
