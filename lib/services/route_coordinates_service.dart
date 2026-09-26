import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class RouteCoordinatesService {
  RouteCoordinatesService._();
  static final RouteCoordinatesService instance = RouteCoordinatesService._();

  // Major Pakistani Cities Coordinates
  static const Map<String, LatLng> cityCoordinates = {
    'lahore': LatLng(31.5204, 74.3587),
    'islamabad': LatLng(33.6844, 73.0479),
    'rawalpindi': LatLng(33.5651, 73.0169),
    'multan': LatLng(30.1575, 71.5249),
    'faisalabad': LatLng(31.4504, 73.1350),
    'karachi': LatLng(24.8607, 67.0011),
    'peshawar': LatLng(34.0151, 71.5249),
    'gujranwala': LatLng(32.1877, 74.1945),
    'sialkot': LatLng(32.4945, 74.5229),
    'bahawalpur': LatLng(29.3544, 71.6911),
    'sukkur': LatLng(27.7052, 68.8574),
    'hyderabad': LatLng(25.3960, 68.3578),
    'abbottabad': LatLng(34.1688, 73.2215),
    'swat': LatLng(35.2227, 72.4258),
    'quetta': LatLng(30.1798, 66.9750),
    'murree': LatLng(33.9070, 73.3943),
    'sahiwal': LatLng(30.6682, 73.1114),
    'sargodha': LatLng(32.0836, 72.6711),
    'rahim yar khan': LatLng(28.4195, 70.3024),
  };

  LatLng getCityCoordinates(String? cityName) {
    if (cityName == null || cityName.trim().isEmpty) {
      return const LatLng(31.5204, 74.3587); // Default Lahore
    }
    final key = cityName.trim().toLowerCase();
    for (var entry in cityCoordinates.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }
    return const LatLng(31.5204, 74.3587);
  }

  // Pre-calculated Detailed Highway Motorway Waypoints
  List<LatLng> getRouteWaypoints(String fromCity, String toCity) {
    final from = fromCity.trim().toLowerCase();
    final to = toCity.trim().toLowerCase();

    // 1. Lahore <-> Islamabad / Rawalpindi (via M-2 Motorway)
    if ((from.contains('lahore') && (to.contains('islamabad') || to.contains('rawalpindi'))) ||
        ((from.contains('islamabad') || from.contains('rawalpindi')) && to.contains('lahore'))) {
      final m2 = [
        const LatLng(31.5204, 74.3587), // Lahore Thokar Niaz Baig
        const LatLng(31.5830, 74.1950), // Babu Sabu Interchange
        const LatLng(31.7820, 73.9850), // Sheikhupura Interchange
        const LatLng(31.9540, 73.7420), // Kot Abdul Malik / Khanqah Dogran
        const LatLng(32.1240, 73.5130), // Sukheki Rest Area
        const LatLng(32.3210, 73.2450), // Pindi Bhattian Interchange (M-2 / M-3 junction)
        const LatLng(32.5340, 73.0820), // Salem / Bhera Service Area
        const LatLng(32.7480, 72.9340), // Kot Momin / Kalar Kahar Salt Range Descent
        const LatLng(32.7820, 72.7120), // Kallar Kahar Service Area
        const LatLng(32.9640, 72.8530), // Balkassar Interchange (Chakwal)
        const LatLng(33.2140, 72.9560), // Neelah Dullah
        const LatLng(33.4350, 72.9820), // Chakri Service Area
        const LatLng(33.5651, 73.0169), // Rawalpindi / Islamabad Toll Plaza
        const LatLng(33.6844, 73.0479), // Islamabad Faizabad Terminal
      ];
      return from.contains('lahore') ? m2 : m2.reversed.toList();
    }

    // 2. Lahore <-> Multan (via M-3 & M-4 Motorway)
    if ((from.contains('lahore') && to.contains('multan')) ||
        (from.contains('multan') && to.contains('lahore'))) {
      final m3m4 = [
        const LatLng(31.5204, 74.3587), // Lahore Terminal
        const LatLng(31.4230, 74.1520), // Faizpur Interchange M-3
        const LatLng(31.3320, 73.9120), // Sharqpur Sharif
        const LatLng(31.2540, 73.6850), // Nankana Sahib Interchange
        const LatLng(31.1820, 73.4120), // Jaranwala
        const LatLng(31.0250, 73.1250), // Samundri Interchange
        const LatLng(30.8540, 72.8420), // Rajana Interchange (Toba Tek Singh)
        const LatLng(30.6850, 72.5630), // Pir Mahal Service Area
        const LatLng(30.5420, 72.2950), // Abdul Hakeem M-3 / M-4 Junction
        const LatLng(30.4120, 72.0450), // Khanewal Interchange
        const LatLng(30.2650, 71.7820), // Shamkot / Multan Ring Road
        const LatLng(30.1575, 71.5249), // Multan Central Terminal (Chungi No. 9)
      ];
      return from.contains('lahore') ? m3m4 : m3m4.reversed.toList();
    }

    // 3. Lahore <-> Faisalabad (via M-3 Motorway)
    if ((from.contains('lahore') && to.contains('faisalabad')) ||
        (from.contains('faisalabad') && to.contains('lahore'))) {
      final m3f = [
        const LatLng(31.5204, 74.3587), // Lahore
        const LatLng(31.4230, 74.1520), // Faizpur
        const LatLng(31.3320, 73.9120), // Sharqpur
        const LatLng(31.2540, 73.6850), // Nankana
        const LatLng(31.3820, 73.4120), // Sahianwala Interchange
        const LatLng(31.4504, 73.1350), // Faisalabad Kohinoor City Terminal
      ];
      return from.contains('lahore') ? m3f : m3f.reversed.toList();
    }

    // 4. Multan <-> Karachi (via M-5 Motorway / Sukkur / Hyderabad)
    if ((from.contains('multan') && to.contains('karachi')) ||
        (from.contains('karachi') && to.contains('multan'))) {
      final m5m9 = [
        const LatLng(30.1575, 71.5249), // Multan Terminal
        const LatLng(29.8540, 71.3250), // Shujabad
        const LatLng(29.5420, 71.1850), // Jalalpur Pirwala
        const LatLng(29.1820, 70.9420), // Uch Sharif
        const LatLng(28.8540, 70.6850), // Zahir Pir
        const LatLng(28.4195, 70.3024), // Rahim Yar Khan
        const LatLng(28.1250, 69.8540), // Ghotki
        const LatLng(27.9540, 69.3250), // Pano Aqil
        const LatLng(27.7052, 68.8574), // Sukkur Rohri Junction
        const LatLng(26.8540, 68.4120), // Moro
        const LatLng(25.9850, 68.3250), // Nawabshah
        const LatLng(25.3960, 68.3578), // Hyderabad M-9 Motorway
        const LatLng(24.9850, 67.4520), // Karachi Toll Plaza M-9
        const LatLng(24.8607, 67.0011), // Karachi Cantt / Sohrab Goth
      ];
      return from.contains('multan') ? m5m9 : m5m9.reversed.toList();
    }

    // 5. Islamabad <-> Peshawar (via M-1 Motorway)
    if ((from.contains('islamabad') && to.contains('peshawar')) ||
        (from.contains('peshawar') && to.contains('islamabad'))) {
      final m1 = [
        const LatLng(33.6844, 73.0479), // Islamabad
        const LatLng(33.6250, 72.8120), // Islamabad Airport M-1 Toll Plaza
        const LatLng(33.7420, 72.4850), // Fateh Jang / Brahma Bahtar
        const LatLng(33.8540, 72.2450), // Burhan / Hassan Abdal (CPEC junction)
        const LatLng(33.9120, 71.9850), // Swabi Interchange
        const LatLng(33.9850, 71.7450), // Rashakai Interchange (Mardan / Swat expressway)
        const LatLng(34.0050, 71.6120), // Charsadda
        const LatLng(34.0151, 71.5249), // Peshawar Ring Road Terminal
      ];
      return from.contains('islamabad') ? m1 : m1.reversed.toList();
    }

    // 6. Generic Smart Interpolation between any 2 Pakistani cities
    final start = getCityCoordinates(fromCity);
    final end = getCityCoordinates(toCity);
    return _generateCurvedPath(start, end, pointsCount: 15);
  }

  // Generates realistic intermediate curve coordinates
  List<LatLng> _generateCurvedPath(LatLng start, LatLng end, {int pointsCount = 15}) {
    final List<LatLng> list = [];
    final midLat = (start.latitude + end.latitude) / 2;
    final midLng = (start.longitude + end.longitude) / 2;
    
    // Slight curve offset for highway feel
    final offsetLat = (end.longitude - start.longitude) * 0.08;
    final offsetLng = -(end.latitude - start.latitude) * 0.08;
    final controlPoint = LatLng(midLat + offsetLat, midLng + offsetLng);

    for (int i = 0; i <= pointsCount; i++) {
      final t = i / pointsCount.toDouble();
      // Quadratic Bezier Formula: B(t) = (1-t)^2 * P0 + 2(1-t)t * P1 + t^2 * P2
      final lat = (1 - t) * (1 - t) * start.latitude + 2 * (1 - t) * t * controlPoint.latitude + t * t * end.latitude;
      final lng = (1 - t) * (1 - t) * start.longitude + 2 * (1 - t) * t * controlPoint.longitude + t * t * end.longitude;
      list.add(LatLng(lat, lng));
    }
    return list;
  }

  // Calculate Bearing / Heading angle (0 to 360 deg) for Bus Rotation
  double calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * (math.pi / 180.0);
    final lon1 = start.longitude * (math.pi / 180.0);
    final lat2 = end.latitude * (math.pi / 180.0);
    final lon2 = end.longitude * (math.pi / 180.0);

    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final radians = math.atan2(y, x);
    final degrees = (radians * 180.0 / math.pi + 360.0) % 360.0;
    return degrees;
  }

  // Haversine Distance in Kilometers
  double calculateDistanceKm(LatLng p1, LatLng p2) {
    const double earthRadiusKm = 6371.0;
    final dLat = (p2.latitude - p1.latitude) * (math.pi / 180.0);
    final dLon = (p2.longitude - p1.longitude) * (math.pi / 180.0);

    final lat1 = p1.latitude * (math.pi / 180.0);
    final lat2 = p2.latitude * (math.pi / 180.0);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) * math.sin(dLon / 2) * math.cos(lat1) * math.cos(lat2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double calculateTotalRouteDistance(List<LatLng> waypoints) {
    if (waypoints.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      total += calculateDistanceKm(waypoints[i], waypoints[i + 1]);
    }
    return total;
  }

  // Find Next Major Rest Stop / Terminal
  String getNextStopName(double progressRatio, String fromCity, String toCity) {
    final from = fromCity.toLowerCase();
    final to = toCity.toLowerCase();

    if (from.contains('lahore') && to.contains('islamabad')) {
      if (progressRatio < 0.25) return "Sukheki Service Area (M-2)";
      if (progressRatio < 0.50) return "Bhera Rest Area & Food Court";
      if (progressRatio < 0.75) return "Kallar Kahar Scenic Interchange";
      if (progressRatio < 0.90) return "Chakri Service Area";
      return "Islamabad Faizabad Terminal";
    }

    if (from.contains('lahore') && to.contains('multan')) {
      if (progressRatio < 0.30) return "Nankana Sahib Service Area";
      if (progressRatio < 0.60) return "Samundri / Rajana Interchange";
      if (progressRatio < 0.85) return "Abdul Hakeem / Khanewal Rest Area";
      return "Multan Central Terminal";
    }

    if (from.contains('multan') && to.contains('karachi')) {
      if (progressRatio < 0.35) return "Rahim Yar Khan Bypass";
      if (progressRatio < 0.65) return "Sukkur Rohri Toll Plaza";
      if (progressRatio < 0.85) return "Hyderabad M-9 Rest Stop";
      return "Karachi Cantt Terminal";
    }

    if (progressRatio < 0.5) return "$fromCity Highway Bypass";
    if (progressRatio < 0.85) return "Midway Service Station";
    return "$toCity Destination Terminal";
  }
}
