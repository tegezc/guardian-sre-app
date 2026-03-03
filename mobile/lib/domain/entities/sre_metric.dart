import 'package:equatable/equatable.dart';

/// Represents a core system metric retrieved from the SRE backend.
/// This entity ensures UI does not depend on raw JSON maps.
class SreMetric extends Equatable {
  final String name;
  final String value;
  final String status;

  const SreMetric({
    required this.name,
    required this.value,
    required this.status,
  });

  @override
  List<Object?> get props => [name, value, status];
}