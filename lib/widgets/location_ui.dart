import 'dart:async';

import 'package:flutter/material.dart';

import '../data/account_api.dart';
import '../data/app_store.dart';
import '../data/location_api.dart';
import '../data/location_service.dart';
import 'common.dart';

class DeviceLocationRow extends StatelessWidget {
  const DeviceLocationRow({super.key, this.enabled = true});
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final location = store.location;
    if (location == null) return const SizedBox.shrink();
    return SettingsRow(
      'Cihaz konumu',
      Icons.my_location,
      subtitle: store.manualCityRequired
          ? 'Bölge belirlenemedi. Keşfettiğin şehri manuel seçebilirsin.'
          : location.state.message,
      onTap: enabled && location.state != DeviceLocationState.loading
          ? location.activateFromUi
          : null,
    );
  }
}

class NearbyResults extends StatefulWidget {
  const NearbyResults({super.key, this.limit = 20, required this.builder});
  final int limit;
  final Widget Function(
    BuildContext context,
    List<NearbyPerson> people,
    String? status,
    VoidCallback retry,
  )
  builder;

  @override
  State<NearbyResults> createState() => _NearbyResultsState();
}

class _NearbyResultsState extends State<NearbyResults> {
  Object? _key;
  Future<LocationResults<NearbyPerson>>? _request;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (ModalRoute.isCurrentOf(context) != false &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        setState(() => _key = null);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final location = store.location!;
    if (!location.allowed || !location.synced) {
      return widget.builder(
        context,
        [],
        location.state.message,
        location.activateFromUi,
      );
    }
    final key = (
      store.city,
      store.radiusMeters,
      store.locationVersion,
      widget.limit,
    );
    if (_key != key) {
      _key = key;
      _request = store.loadNearby(limit: widget.limit);
    }
    return FutureBuilder(
      future: _request,
      builder: (context, snapshot) {
        final error = snapshot.error;
        final people =
            snapshot.data?.items
                .where((item) => !store.blocked.contains(item.person.id))
                .toList() ??
            <NearbyPerson>[];
        final status = error is ApiFailure
            ? error.detail
            : error != null
            ? 'Yakındaki kişiler yüklenemedi.'
            : snapshot.data?.permissionRequired == true
            ? 'Konumunu güncelle.'
            : !snapshot.hasData
            ? 'Yakındaki kişiler yükleniyor…'
            : people.isEmpty
            ? 'Yakında görünür kimse bulunamadı.'
            : null;
        return widget.builder(context, people, status, () async {
          if (snapshot.data?.permissionRequired == true) {
            await location.refresh(force: true);
          }
          if (!mounted) return;
          setState(() {
            _request = store.loadNearby(limit: widget.limit, refresh: true);
          });
        });
      },
    );
  }
}
