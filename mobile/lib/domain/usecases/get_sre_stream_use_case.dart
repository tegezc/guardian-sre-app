import '../entities/sre_message.dart';
import '../repositories/sre_repository.dart';

/// Use case to initialize and listen to the live SRE agent stream.
class GetSreStreamUseCase {
  final SreRepository repository;

  GetSreStreamUseCase(this.repository);

  Stream<SreMessage> execute() {
    return repository.getSreStream();
  }
}