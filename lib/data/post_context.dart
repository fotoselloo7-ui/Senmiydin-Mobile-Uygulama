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
    this.originPlaceId,
    this.destinationPlaceId,
    this.originLabel,
    this.destinationLabel,
  });
  factory TravelDetails.fromJson(Map<String, dynamic> json) => TravelDetails(
    originLabel: (json['origin'] as Map<String, dynamic>)['label'] as String?,
    destinationLabel:
        (json['destination'] as Map<String, dynamic>)['label'] as String?,
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

  /// The places picked for departure / arrival (as fine as a neighbourhood); null on older journeys.
  final int? originPlaceId, destinationPlaceId;
  final String? originLabel, destinationLabel;
  String get originText => originLabel ?? origin.name;
  String get destinationText => destinationLabel ?? destination.name;
  final DateTime? departureAt;
  final bool isPublic;
  Map<String, Object?> toJson() => {
    'transport_type': transport,
    'origin_city_id': origin.id,
    'destination_city_id': destination.id,
    'origin_place_id': ?originPlaceId,
    'destination_place_id': ?destinationPlaceId,
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

  /// Labels shown in the form; [originPlace] / [destinationPlace] hold the places picked with the location picker.
  String? origin, destination;
  ChosenPlace? originPlace, destinationPlace;
  DateTime? departureAt;
  Future<TravelDetails?> resolve(
    Future<int> Function(String) cityId,
    String defaultCity,
  ) async {
    if (!enabled) return null;
    if (destination == null) {
      throw const ApiFailure('Yolculuğun varış yerini seç.');
    }
    return TravelDetails(
      transport: transport,
      origin:
          originPlace?.city ??
          CatalogItem(
            await cityId(origin ?? defaultCity),
            origin ?? defaultCity,
          ),
      destination:
          destinationPlace?.city ??
          CatalogItem(await cityId(destination!), destination!),
      originPlaceId: originPlace?.placeId,
      destinationPlaceId: destinationPlace?.placeId,
      originLabel: originPlace?.label,
      destinationLabel: destinationPlace?.label,
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
