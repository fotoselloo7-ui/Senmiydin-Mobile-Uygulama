import '../core/service_availability.dart';

class VersionPolicy {
  const VersionPolicy(this.latest, this.url, {required this.required});
  final String latest;
  final Uri url;
  final bool required;

  static int? compare(String left, String right) {
    List<int>? parts(String value) {
      if (!RegExp(
        r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:\+[0-9]+)?$',
      ).hasMatch(value)) {
        return null;
      }
      return value.split('+').first.split('.').map(int.parse).toList();
    }

    final a = parts(left), b = parts(right);
    if (a == null || b == null) return null;
    for (var i = 0; i < 3; i++) {
      final difference = a[i].compareTo(b[i]);
      if (difference != 0) return difference;
    }
    return 0;
  }

  static VersionPolicy? fromJson(
    String current,
    String platform,
    Map<String, dynamic>? values,
  ) {
    if (values == null) return null;
    final url = Uri.tryParse(values['url'] as String? ?? '');
    if (!ServiceAvailability.store(url, platform)) return null;
    final minimum = values['minimum'] as String? ?? '';
    final latest = values['latest'] as String? ?? '';
    final required = (compare(current, minimum) ?? 0) < 0;
    if (!required && (compare(current, latest) ?? 0) >= 0) return null;
    return VersionPolicy(
      latest.isEmpty ? minimum : latest,
      url!,
      required: required,
    );
  }
}
