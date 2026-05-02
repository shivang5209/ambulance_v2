import 'city_graph.dart';

CityGraph buildDemoCityGraph() {
  final graph = CityGraph.empty();

  // Approximate positions around central Delhi for demo simulation.
  graph.addNode(const RoadNode(
    id: 'ambulance_base',
    point: GeoPoint(latitude: 28.6139, longitude: 77.2090),
  ));
  graph.addNode(const RoadNode(
    id: 'sector_a',
    point: GeoPoint(latitude: 28.6202, longitude: 77.2119),
  ));
  graph.addNode(const RoadNode(
    id: 'sector_b',
    point: GeoPoint(latitude: 28.6078, longitude: 77.2180),
  ));
  graph.addNode(const RoadNode(
    id: 'sector_c',
    point: GeoPoint(latitude: 28.6015, longitude: 77.2061),
  ));
  graph.addNode(const RoadNode(
    id: 'sector_d',
    point: GeoPoint(latitude: 28.6184, longitude: 77.1984),
  ));
  graph.addNode(const RoadNode(
    id: 'sector_e',
    point: GeoPoint(latitude: 28.6261, longitude: 77.2221),
  ));

  graph.addBidirectionalEdge(
      nodeA: 'ambulance_base',
      nodeB: 'sector_a',
      baseTravelTimeMinutes: 4.0,
      trafficMultiplier: 1.1);
  graph.addBidirectionalEdge(
      nodeA: 'ambulance_base',
      nodeB: 'sector_b',
      baseTravelTimeMinutes: 5.0,
      trafficMultiplier: 1.2);
  graph.addBidirectionalEdge(
      nodeA: 'ambulance_base',
      nodeB: 'sector_c',
      baseTravelTimeMinutes: 6.0,
      trafficMultiplier: 1.0);
  graph.addBidirectionalEdge(
      nodeA: 'ambulance_base',
      nodeB: 'sector_d',
      baseTravelTimeMinutes: 5.5,
      trafficMultiplier: 1.05);

  graph.addBidirectionalEdge(
      nodeA: 'sector_a',
      nodeB: 'sector_b',
      baseTravelTimeMinutes: 3.0,
      trafficMultiplier: 1.3);
  graph.addBidirectionalEdge(
      nodeA: 'sector_b',
      nodeB: 'sector_c',
      baseTravelTimeMinutes: 3.5,
      trafficMultiplier: 1.1);
  graph.addBidirectionalEdge(
      nodeA: 'sector_c',
      nodeB: 'sector_d',
      baseTravelTimeMinutes: 2.8,
      trafficMultiplier: 1.0);
  graph.addBidirectionalEdge(
      nodeA: 'sector_d',
      nodeB: 'sector_a',
      baseTravelTimeMinutes: 3.4,
      trafficMultiplier: 1.15);
  graph.addBidirectionalEdge(
      nodeA: 'sector_a',
      nodeB: 'sector_e',
      baseTravelTimeMinutes: 4.5,
      trafficMultiplier: 1.2);
  graph.addBidirectionalEdge(
      nodeA: 'sector_b',
      nodeB: 'sector_e',
      baseTravelTimeMinutes: 4.2,
      trafficMultiplier: 1.1);

  return graph;
}
