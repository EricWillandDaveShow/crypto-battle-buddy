import 'dart:html' as html;

String? readSelectedFeedImpl() {
  try {
    return html.window.localStorage['selected_feed_platform'];
  } catch (_) {
    return null;
  }
}

void writeSelectedFeedImpl(String value) {
  try {
    html.window.localStorage['selected_feed_platform'] = value;
  } catch (_) {}
}

String? readQueryParamImpl(String key) {
  try {
    final uri = Uri.parse(html.window.location.href);
    return uri.queryParameters[key];
  } catch (_) {
    return null;
  }
}

void replaceQueryParamImpl(String key, String value) {
  try {
    final uri = Uri.parse(html.window.location.href);
    final qp = Map<String, String>.from(uri.queryParameters);
    qp[key] = value;
    final newUri = uri.replace(queryParameters: qp);
    html.window.history.replaceState(null, '', newUri.toString());
  } catch (_) {}
}
