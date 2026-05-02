import 'dart:async';
import 'dart:math';

import '../models/ambulance_request.dart';
import 'routing/demo_city_graph.dart';
import 'routing/fastest_route_service.dart';

class MockAmbulanceService {
  final FastestRouteService _routeService;

  // Simulated city graph used by mock dispatch until backend routing is connected.
  final _cityGraph = buildDemoCityGraph();

  static const _dispatchBaseNode = 'ambulance_base';
  static const _incidentNodes = [
    'sector_a',
    'sector_b',
    'sector_c',
    'sector_d',
    'sector_e',
  ];

  MockAmbulanceService({FastestRouteService? routeService})
      : _routeService = routeService ?? FastestRouteService();

  // Simulate network call to request ambulance
  Future<AmbulanceResponse> requestAmbulance(AmbulanceRequest req) async {
    // simulate network latency
    await Future.delayed(const Duration(seconds: 2));

    final rand = Random();
    final incidentNode = _mapAddressToIncidentNode(req.address);

    final route = _routeService.findFastestRoute(
      graph: _cityGraph,
      sourceNodeId: _dispatchBaseNode,
      targetNodeId: incidentNode,
      preferredAlgorithm: RoutingAlgorithm.aStar,
    );

    // Keep ETA practical for UI while still using route-driven travel time.
    final eta = max(2, route.totalTravelTimeMinutes.ceil());
    final id = 'AMB-${1000 + rand.nextInt(9000)}';

    return AmbulanceResponse(
      ambulanceId: id,
      etaMinutes: eta,
      status: 'dispatched',
      routeAlgorithm: route.algorithmUsed.name,
      routeNodePath: route.nodePath,
    );
  }

  String _mapAddressToIncidentNode(String address) {
    if (address.trim().isEmpty) {
      return _incidentNodes.first;
    }

    final index = address.toLowerCase().hashCode.abs() % _incidentNodes.length;
    return _incidentNodes[index];
  }

  // Simulate cancellation
  Future<bool> cancelRequest(String ambulanceId) async {
    await Future.delayed(const Duration(seconds: 1));
    // 90% chance of success
    return Random().nextInt(10) < 9;
  }
}
