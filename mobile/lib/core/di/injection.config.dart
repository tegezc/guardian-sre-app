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
import 'package:mobile/data/repositories/sre_repository_impl.dart' as _i269;
import 'package:mobile/domain/repositories/sre_repository.dart' as _i949;
import 'package:mobile/domain/usecases/get_sre_stream_use_case.dart' as _i352;
import 'package:mobile/presentation/bloc/sre_bloc.dart' as _i422;

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
    gh.singleton<_i949.SreRepository>(
      () => _i269.SreRepositoryImpl(gh<_i512.SreRemoteDataSource>()),
    );
    gh.factory<_i352.GetSreStreamUseCase>(
      () => _i352.GetSreStreamUseCase(gh<_i949.SreRepository>()),
    );
    gh.factory<_i422.SreBloc>(
      () => _i422.SreBloc(
        gh<_i352.GetSreStreamUseCase>(),
        gh<_i949.SreRepository>(),
      ),
    );
    return this;
  }
}

class _$RegisterModule extends _i815.RegisterModule {}
