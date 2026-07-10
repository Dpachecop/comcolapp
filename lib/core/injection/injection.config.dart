// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:comcolapp/features/food_detection/data/datasources/tflite_local_data_source.dart'
    as _i248;
import 'package:comcolapp/features/food_detection/data/repositories/food_detection_repository_impl.dart'
    as _i917;
import 'package:comcolapp/features/food_detection/domain/repositories/food_detection_repository.dart'
    as _i252;
import 'package:comcolapp/features/food_detection/presentation/bloc/camera_bloc.dart'
    as _i1005;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.lazySingleton<_i248.TfliteLocalDataSource>(
      () => _i248.TfliteLocalDataSourceImpl(),
    );
    gh.factory<_i252.FoodDetectionRepository>(
      () =>
          _i917.FoodDetectionRepositoryImpl(gh<_i248.TfliteLocalDataSource>()),
    );
    gh.factory<_i1005.CameraBloc>(
      () => _i1005.CameraBloc(
        gh<_i252.FoodDetectionRepository>(),
        gh<_i248.TfliteLocalDataSource>(),
      ),
    );
    return this;
  }
}
