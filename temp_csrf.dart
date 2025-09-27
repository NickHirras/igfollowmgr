  // Helper method to extract CSRF token from HTML
  String? _extractCsrfToken(String html) {
    // Try multiple patterns to find CSRF token
    final patterns = [
      r'"csrf_token":"([^"]+)"',
      r'csrf_token["\']?\s*:\s*["\']([^"\']+)["\']',
      r'name=["\']csrfmiddlewaretoken["\']\s+value=["\']([^"\']+)["\']',
      r'<input[^>]*name=["\']csrfmiddlewaretoken["\']\s+value=["\']([^"\']+)["\']',
      r'window\._sharedData\s*=\s*\{[^}]*"csrf_token":"([^"]+)"',
      r'"csrfToken":"([^"]+)"',
      r'csrf["\']?\s*:\s*["\']([^"\']+)["\']',
    ];
    
    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(html);
      if (match != null && match.group(1) != null && match.group(1)!.isNotEmpty) {
        return match.group(1);
      }
    }
    
    // If no pattern matches, log a portion of the HTML for debugging
    if (kDebugMode) {
      print('CSRF extraction failed. HTML sample:');
      print(html.length > 1000 ? html.substring(0, 1000) + '...' : html);
    }
    
    return null;
  }
