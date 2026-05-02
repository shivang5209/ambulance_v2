import 'dart:math' as math;

import 'city_graph.dart';

enum RoutingAlgorithm {
  aStar,
  dijkstra,
}

class FastestRouteResult {
  final List<String> nodePath;
  final double totalTravelTimeMinutes;
  final RoutingAlgorithm algorithmUsed;

  const FastestRouteResult({
    required this.nodePath,
    required this.totalTravelTimeMinutes,
    required this.algorithmUsed,
  });
}

class FastestRouteService {
  FastestRouteResult findFastestRoute({
    required CityGraph graph,
    required String sourceNodeId,
    required String targetNodeId,
    RoutingAlgorithm preferredAlgorithm = RoutingAlgorithm.aStar,
  }) {
    if (!graph.nodes.containsKey(sourceNodeId)) {
      throw ArgumentError('Unknown source node: $sourceNodeId');
    }
    if (!graph.nodes.containsKey(targetNodeId)) {
      throw ArgumentError('Unknown target node: $targetNodeId');
    }

    if (preferredAlgorithm == RoutingAlgorithm.aStar) {
      final result = _aStar(
        graph: graph,
        sourceNodeId: sourceNodeId,
        targetNodeId: targetNodeId,
      );

      if (result != null) {
        return FastestRouteResult(
          nodePath: result.path,
          totalTravelTimeMinutes: result.totalCost,
          algorithmUsed: RoutingAlgorithm.aStar,
        );
      }

      // Fallback to Dijkstra when A* cannot resolve a route.
      final fallback = _dijkstra(
        graph: graph,
        sourceNodeId: sourceNodeId,
        targetNodeId: targetNodeId,
      );

      if (fallback != null) {
        return FastestRouteResult(
          nodePath: fallback.path,
          totalTravelTimeMinutes: fallback.totalCost,
          algorithmUsed: RoutingAlgorithm.dijkstra,
        );
      }

      throw StateError(
          'No route found between $sourceNodeId and $targetNodeId');
    }

    final result = _dijkstra(
      graph: graph,
      sourceNodeId: sourceNodeId,
      targetNodeId: targetNodeId,
    );

    if (result == null) {
      throw StateError(
          'No route found between $sourceNodeId and $targetNodeId');
    }

    return FastestRouteResult(
      nodePath: result.path,
      totalTravelTimeMinutes: result.totalCost,
      algorithmUsed: RoutingAlgorithm.dijkstra,
    );
  }

  _PathResult? _aStar({
    required CityGraph graph,
    required String sourceNodeId,
    required String targetNodeId,
  }) {
    final openSet = <String>{sourceNodeId};

    final gScore = <String, double>{
      for (final id in graph.nodes.keys) id: double.infinity,
    };
    final fScore = <String, double>{
      for (final id in graph.nodes.keys) id: double.infinity,
    };

    gScore[sourceNodeId] = 0;
    fScore[sourceNodeId] = _heuristicMinutes(
      graph.nodes[sourceNodeId]!,
      graph.nodes[targetNodeId]!,
    );

    final cameFrom = <String, String>{};

    while (openSet.isNotEmpty) {
      final current = _extractMinByScore(openSet, fScore);
      if (current == targetNodeId) {
        return _PathResult(
          path: _reconstructPath(cameFrom, current),
          totalCost: gScore[current]!,
        );
      }

      openSet.remove(current);

      final neighbors = graph.adjacency[current] ?? const <RoadEdge>[];
      for (final edge in neighbors) {
        final tentativeG = gScore[current]! + edge.travelTimeMinutes;
        if (tentativeG < (gScore[edge.toNodeId] ?? double.infinity)) {
          cameFrom[edge.toNodeId] = current;
          gScore[edge.toNodeId] = tentativeG;
          fScore[edge.toNodeId] = tentativeG +
              _heuristicMinutes(
                graph.nodes[edge.toNodeId]!,
                graph.nodes[targetNodeId]!,
              );
          openSet.add(edge.toNodeId);
        }
      }
    }

    return null;
  }

  _PathResult? _dijkstra({
    required CityGraph graph,
    required String sourceNodeId,
    required String targetNodeId,
  }) {
    final unvisited = <String>{...graph.nodes.keys};

    final distance = <String, double>{
      for (final id in graph.nodes.keys) id: double.infinity,
    };

    final cameFrom = <String, String>{};
    distance[sourceNodeId] = 0;

    while (unvisited.isNotEmpty) {
      final current = _extractMinByScore(unvisited, distance);

      if (distance[current] == double.infinity) {
        break;
      }

      if (current == targetNodeId) {
        return _PathResult(
          path: _reconstructPath(cameFrom, current),
          totalCost: distance[current]!,
        );
      }

      unvisited.remove(current);

      final neighbors = graph.adjacency[current] ?? const <RoadEdge>[];
      for (final edge in neighbors) {
        if (!unvisited.contains(edge.toNodeId)) {
          continue;
        }

        final alternative = distance[current]! + edge.travelTimeMinutes;
        if (alternative < (distance[edge.toNodeId] ?? double.infinity)) {
          distance[edge.toNodeId] = alternative;
          cameFrom[edge.toNodeId] = current;
        }
      }
    }

    return null;
  }

  String _extractMinByScore(
      Set<String> candidateNodeIds, Map<String, double> score) {
    if (candidateNodeIds.isEmpty) {
      throw StateError('Cannot extract minimum from an empty candidate set');
    }

    final iterator = candidateNodeIds.iterator;
    iterator.moveNext();
    var bestNode = iterator.current;
    var bestScore = score[bestNode] ?? double.infinity;

    for (final nodeId in candidateNodeIds) {
      final s = score[nodeId] ?? double.infinity;
      if (s < bestScore) {
        bestScore = s;
        bestNode = nodeId;
      }
    }

    return bestNode;
  }

  List<String> _reconstructPath(Map<String, String> cameFrom, String current) {
    final path = <String>[current];
    var cursor = current;

    while (cameFrom.containsKey(cursor)) {
      cursor = cameFrom[cursor]!;
      path.insert(0, cursor);
    }

    return path;
  }

  double _heuristicMinutes(RoadNode nodeA, RoadNode nodeB) {
    // Straight-line estimate converted to minutes at a conservative average city speed.
    const avgCitySpeedKmPerHour = 40.0;
    final distanceKm = _haversineKm(nodeA.point, nodeB.point);
    return (distanceKm / avgCitySpeedKmPerHour) * 60.0;
  }

  double _haversineKm(GeoPoint p1, GeoPoint p2) {
    const earthRadiusKm = 6371.0;

    final lat1 = _degToRad(p1.latitude);
    final lat2 = _degToRad(p2.latitude);
    final dLat = _degToRad(p2.latitude - p1.latitude);
    final dLon = _degToRad(p2.longitude - p1.longitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _degToRad(double degree) => degree * (math.pi / 180.0);
}

class _PathResult {
  final List<String> path;
  final double totalCost;

  const _PathResult({required this.path, required this.totalCost});
}
