/// A video's size for the large-video warning, base 1024: whole MB below
/// 1 GiB ("742 MB"), else one-decimal GB ("1.3 GB").
String formatVideoSize(int bytes) {
  const mib = 1024 * 1024;
  const gib = 1024 * mib;
  if (bytes < gib) return '${(bytes / mib).round()} MB';
  return '${(bytes / gib).toStringAsFixed(1)} GB';
}
