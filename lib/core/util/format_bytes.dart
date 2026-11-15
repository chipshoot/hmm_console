/// A video's size for the large-video warning and Settings -> Videos, base
/// 1024: whole MB below 1 GiB ("742 MB"), else one-decimal GB ("1.3 GB"),
/// with a trailing ".0" dropped ("2 GB").
String formatVideoSize(int bytes) {
  const mib = 1024 * 1024;
  const gib = 1024 * mib;
  if (bytes < gib) return '${(bytes / mib).round()} MB';
  final gb = (bytes / gib).toStringAsFixed(1);
  return '${gb.endsWith('.0') ? gb.substring(0, gb.length - 2) : gb} GB';
}
