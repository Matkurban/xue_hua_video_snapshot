/// Canonical `file://` URI for a local path or existing file URI.
String normalizeFileUri(String pathOrUri) {
  if (pathOrUri.startsWith('file://')) {
    return Uri.parse(pathOrUri).toString();
  }
  return Uri.file(pathOrUri).toString();
}
