String normalizeAssDisplayText(String value) {
  return value
      .replaceAll(RegExp(r'\{[^}]*\}'), '')
      .replaceAll(RegExp(r'\\+[hH]'), ' ')
      .replaceAll(RegExp(r'\\+[nN]'), ' ')
      .replaceAll(RegExp(r'\\+[A-Za-z]+-?\d*(?:\.\d+)?'), ' ')
      .replaceAll(RegExp(r'\\+'), ' ')
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
