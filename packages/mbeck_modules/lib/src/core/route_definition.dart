import 'package:shelf/shelf.dart';

/// Defines an HTTP route that a module provides.
/// 
/// Modules register these routes with the seller's HTTP server
/// during activation.
class RouteDefinition {
  /// HTTP method (GET, POST, PUT, DELETE)
  final String method;

  /// Route path (e.g., '/api/v1/services/catalog')
  final String path;

  /// Route handler function
  final Future<Response> Function(Request request) handler;

  /// Description for documentation
  final String? description;

  const RouteDefinition({
    required this.method,
    required this.path,
    required this.handler,
    this.description,
  });

  @override
  String toString() => 'RouteDefinition($method $path)';
}
