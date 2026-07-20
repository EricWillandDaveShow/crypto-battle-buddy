import 'web_env_stub.dart' if (dart.library.html) 'web_env_web.dart';

String? readSelectedFeed() => readSelectedFeedImpl();
void writeSelectedFeed(String value) => writeSelectedFeedImpl(value);
String? readQueryParam(String key) => readQueryParamImpl(key);
void replaceQueryParam(String key, String value) => replaceQueryParamImpl(key, value);
