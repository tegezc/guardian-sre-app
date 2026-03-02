import 'package:injectable/injectable.dart';

@module
abstract class RegisterModule {
  // Injecting the backend URL as a named dependency
  @Named("baseUrl")
  String get baseUrl => "ws://10.15.224.101:8080";
}