import 'account_api.dart';

class HistoricalPlace {
  HistoricalPlace.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      cityId = json['city_id'] as int,
      city = json['city_name'] as String,
      label = json['label'] as String,
      recordedAt = DateTime.parse(json['recorded_at'] as String).toLocal();
  final int id, cityId;
  final String city, label;
  final DateTime recordedAt;
}

class PostPlaceSelection {
  const PostPlaceSelection(
    this.source, {
    this.historyId,
    this.latitude,
    this.longitude,
    this.city,
    this.label,
    this.recordedAt,
  });
  final String source;
  final int? historyId;
  final double? latitude, longitude;
  final String? city, label;
  final DateTime? recordedAt;
  Map<String, Object?> toJson() => {
    'location_source': source,
    if (historyId != null) 'history_id': historyId,
    if (latitude != null) 'place_latitude': latitude,
    if (longitude != null) 'place_longitude': longitude,
  };
}

const transportLabels = {
  'bus': 'Otobüs',
  'train': 'Tren',
  'plane': 'Uçak',
  'ferry': 'Feribot',
  'other': 'Diğer',
};

class TravelDetails {
  TravelDetails({
    required this.transport,
    required this.origin,
    required this.destination,
    this.departureAt,
    this.operatorName = '',
    this.serviceCode = '',
    this.vehicleIdentifier = '',
    this.isPublic = false,
  });
  factory TravelDetails.fromJson(Map<String, dynamic> json) => TravelDetails(
    transport: json['transport_type'] as String,
    origin: CatalogItem.fromJson(json['origin'] as Map<String, dynamic>),
    destination: CatalogItem.fromJson(
      json['destination'] as Map<String, dynamic>,
    ),
    departureAt: DateTime.tryParse(json['departure_at'] as String? ?? '')
        ?.toLocal(),
    operatorName: json['operator_name'] as String? ?? '',
    serviceCode: json['service_code'] as String? ?? '',
    vehicleIdentifier: json['vehicle_identifier'] as String? ?? '',
    isPublic: json['is_public'] == true,
  );
  final String transport, operatorName, serviceCode, vehicleIdentifier;
  final CatalogItem origin, destination;
  final DateTime? departureAt;
  final bool isPublic;
  Map<String, Object?> toJson() => {
    'transport_type': transport,
    'origin_city_id': origin.id,
    'destination_city_id': destination.id,
    if (departureAt != null)
      'departure_at': departureAt!.toUtc().toIso8601String(),
    'operator_name': operatorName,
    'service_code': serviceCode,
    'vehicle_identifier': vehicleIdentifier,
    'is_public': isPublic ? 1 : 0,
  };
}

class TravelDraft {
  bool enabled = false, isPublic = false;
  String transport = 'bus',
      operatorName = '',
      serviceCode = '',
      vehicleIdentifier = '';
  String? origin, destination;
  DateTime? departureAt;
  Future<TravelDetails?> resolve(
    Future<int> Function(String) cityId,
    String defaultCity,
  ) async {
    if (!enabled) return null;
    if (destination == null) {
      throw const ApiFailure('Yolculuğun varış şehrini seç.');
    }
    return TravelDetails(
      transport: transport,
      origin: CatalogItem(
        await cityId(origin ?? defaultCity),
        origin ?? defaultCity,
      ),
      destination: CatalogItem(await cityId(destination!), destination!),
      departureAt: departureAt,
      operatorName: operatorName.trim(),
      serviceCode: serviceCode.trim(),
      vehicleIdentifier: vehicleIdentifier.trim(),
      isPublic: isPublic,
    );
  }
}

String contextDate(DateTime value) =>
    '${value.day}.${value.month}.${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
