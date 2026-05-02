class GeoPoint {
  final double latitude;
  final double longitude;

  const GeoPoint({
    required this.latitude,
    required this.longitude,
  });
}

class RoadNode {
  final String id;
  final GeoPoint point;

  const RoadNode({
    required this.id,
    required this.point,
  });
}

class RoadEdge {
  final String fromNodeId;
  final String toNodeId;
  final double baseTravelTimeMinutes;
  final double trafficMultiplier;

  const RoadEdge({
    required this.fromNodeId,
    required this.toNodeId,
    required this.baseTravelTimeMinutes,
    this.trafficMultiplier = 1.0,
  });

  double get travelTimeMinutes => baseTravelTimeMinutes * trafficMultiplier;
}

class CityGraph {
  final Map<String, RoadNode> nodes;
  final Map<String, List<RoadEdge>> adjacency;

  CityGraph({
    required this.nodes,
    required this.adjacency,
  });

  factory CityGraph.empty() {
    return CityGraph(
        nodes: <String, RoadNode>{}, adjacency: <String, List<RoadEdge>>{});
  }

  void addNode(RoadNode node) {
    nodes[node.id] = node;
    adjacency.putIfAbsent(node.id, () => <RoadEdge>[]);
  }

  void addDirectedEdge({
    required String fromNodeId,
    required String toNodeId,
    required double baseTravelTimeMinutes,
    double trafficMultiplier = 1.0,
  }) {
    adjacency.putIfAbsent(fromNodeId, () => <RoadEdge>[]);
    adjacency[fromNodeId]!.add(
      RoadEdge(
        fromNodeId: fromNodeId,
        toNodeId: toNodeId,
        baseTravelTimeMinutes: baseTravelTimeMinutes,
        trafficMultiplier: trafficMultiplier,
      ),
    );
  }

  void addBidirectionalEdge({
    required String nodeA,
    required String nodeB,
    required double baseTravelTimeMinutes,
    double trafficMultiplier = 1.0,
  }) {
    addDirectedEdge(
      fromNodeId: nodeA,
      toNodeId: nodeB,
      baseTravelTimeMinutes: baseTravelTimeMinutes,
      trafficMultiplier: trafficMultiplier,
    );
    addDirectedEdge(
      fromNodeId: nodeB,
      toNodeId: nodeA,
      baseTravelTimeMinutes: baseTravelTimeMinutes,
      trafficMultiplier: trafficMultiplier,
    );
  }
}
