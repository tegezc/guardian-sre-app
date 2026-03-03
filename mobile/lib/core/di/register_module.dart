import 'package:injectable/injectable.dart';

/// Module to register third-party dependencies and environment variables
/// for the Injectable code generator.
@module
abstract class RegisterModule {
  /// Provides the base URL for the WebSocket connection.
  /// IMPORTANT: Change this to your laptop's local IP when testing on a real device.
  @Named("baseUrl")
  String get baseUrl => 'ws://10.15.224.101:8080';
}