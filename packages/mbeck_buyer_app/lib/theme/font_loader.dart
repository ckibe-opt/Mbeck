import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Abstract loader to allow mocking font fetching in tests
abstract class FontLoader {
  TextStyle getFont(String fontFamily);
}

/// Real implementation using Google Fonts
class GoogleFontLoader implements FontLoader {
  const GoogleFontLoader();

  @override
  TextStyle getFont(String fontFamily) {
    return GoogleFonts.getFont(fontFamily);
  }
}

/// Mock loader for tests (returns basic text style)
class MockFontLoader implements FontLoader {
  const MockFontLoader();
  
  @override
  TextStyle getFont(String fontFamily) {
    // Return a dummy style with the requested family name
    return TextStyle(fontFamily: fontFamily);
  }
}
