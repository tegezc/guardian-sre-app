// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:mobile/core/di/register_module.dart' as _i815;
import 'package:mobile/data/datasources/sre_remote_data_source.dart' as _i512;
import 'package:mobile/data/repositories/voice_repository_impl.dart' as _i771;
import 'package:mobile/domain/repositories/voice_repository.dart' as _i372;
import 'package:mobile/domain/usecases/connect_voice_stream.dart' as _i967;
import 'package:mobile/domain/usecases/disconnect_voice_stream.dart' as _i349;
import 'package:mobile/domain/usecases/send_audio_chunk.dart' as _i1071;
import 'package:mobile/presentation/bloc/voice_bloc.dart' as _i1052;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final registerModule = _$RegisterModule();
    gh.factory<String>(() => registerModule.baseUrl, instanceName: 'baseUrl');
    gh.lazySingleton<_i512.SreRemoteDataSource>(
      () => _i512.SreRemoteDataSourceImpl(gh<String>(instanceName: 'baseUrl')),
    );
    gh.factory<_i372.VoiceRepository>(
      () => _i771.VoiceRepositoryImpl(gh<_i512.SreRemoteDataSource>()),
    );
    gh.lazySingleton<_i967.ConnectVoiceStreamUseCase>(
      () => _i967.ConnectVoiceStreamUseCase(gh<_i372.VoiceRepository>()),
    );
    gh.lazySingleton<_i349.DisconnectVoiceStreamUseCase>(
      () => _i349.DisconnectVoiceStreamUseCase(gh<_i372.VoiceRepository>()),
    );
    gh.lazySingleton<_i1071.SendAudioChunkUseCase>(
      () => _i1071.SendAudioChunkUseCase(gh<_i372.VoiceRepository>()),
    );
    gh.factory<_i1052.VoiceBloc>(
      () => _i1052.VoiceBloc(
        gh<_i967.ConnectVoiceStreamUseCase>(),
        gh<_i1071.SendAudioChunkUseCase>(),
        gh<_i349.DisconnectVoiceStreamUseCase>(),
      ),
    );
    return this;
  }
}

class _$RegisterModule extends _i815.RegisterModule {}
