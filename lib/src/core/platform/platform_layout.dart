import 'package:flutter/foundation.dart';

/// True only on Windows desktop builds (not web, not mobile).
bool get isWindowsApp =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
