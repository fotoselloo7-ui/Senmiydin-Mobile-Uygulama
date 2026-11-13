import 'models.dart';

class NearbyPerson {
  const NearbyPerson(this.person, this.meters);
  final Person person;
  final int meters;
}

class MapPostPoint {
  MapPostPoint.fromJson(Map<String, dynamic> data)
    : id = data['post_id'].toString(),
      latitude = (data['latitude'] as num).toDouble(),
      longitude = (data['longitude'] as num).toDouble(),
      meters = data['distance_meters'] as int?;

  final String id;
  final double latitude, longitude;
  final int? meters;
}

class LocationResults<T> {
  const LocationResults(this.items, {this.permissionRequired = false});
  final List<T> items;
  final bool permissionRequired;
}

String locationDistance(int meters) => meters < 1000
    ? '$meters m'
    : '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
