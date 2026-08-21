/// Short catalog title when seed uses `Category Brand N` pattern.
String catalogProductTitle(String name, String brand) {
  final brandMarker = ' $brand ';
  final index = name.indexOf(brandMarker);
  if (index > 0) {
    final prefix = name.substring(0, index).trim();
    final suffix = name.substring(index + brandMarker.length).trim();
    if (prefix.length > 12 && suffix.isNotEmpty) {
      return '$brand $suffix';
    }
  }
  return name;
}
