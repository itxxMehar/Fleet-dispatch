import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/admin_repository_impl.dart';
import '../../data/repositories/alert_repository_impl.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../data/repositories/driver_repository_impl.dart';
import '../../data/repositories/health_repository.dart';
import '../../data/repositories/kpi_repository_impl.dart';
import '../../data/repositories/session_repository_impl.dart';
import '../../data/repositories/trip_repository_impl.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/repositories/alert_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/driver_repository.dart';
import '../../domain/repositories/kpi_repository.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/repositories/trip_repository.dart';
import '../../domain/usecases/alert_actions.dart';
import '../../domain/usecases/get_driver.dart';
import '../../domain/usecases/get_kpis.dart';
import '../../domain/usecases/get_me.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/trip_actions.dart';
import '../../presentation/connectivity/connectivity_bloc.dart';
import '../../presentation/session/session_bloc.dart';
import '../auth/token_persistence.dart';
import '../auth/token_store.dart';
import '../config/app_config.dart';
import '../network/graphql_client.dart';
import '../network/rest_client.dart';
import '../realtime/drivers_locations_client.dart';
import '../realtime/ops_events_client.dart';
import '../realtime/sse_transport.dart';
import '../realtime/ws_transport.dart';

final sl = GetIt.instance;

void configureDependencies({
  AppConfig? config,
  http.Client? httpClient,
  TokenPersistence? tokenPersistence,
  SharedPreferences? sharedPreferences,
  SseTransport? sseTransport,
  WebSocketTransport? webSocketTransport,
}) {
  if (sl.isRegistered<AppConfig>()) {
    return;
  }

  final resolvedConfig = config ?? AppConfig.fromEnvironment();
  final client = httpClient ?? http.Client();
  final persistence =
      tokenPersistence ??
      (sharedPreferences != null
          ? SharedPreferencesTokenPersistence(sharedPreferences)
          : MemoryTokenPersistence());

  sl
    ..registerSingleton<AppConfig>(resolvedConfig)
    ..registerSingleton<http.Client>(client)
    ..registerSingleton<TokenPersistence>(persistence)
    ..registerLazySingleton<TokenStore>(() => TokenStore(persistence: sl()))
    ..registerLazySingleton<RestClient>(
      () => RestClient(config: sl(), tokenStore: sl(), httpClient: sl()),
    )
    ..registerLazySingleton<GraphQlClient>(
      () => GraphQlClient(config: sl(), tokenStore: sl(), httpClient: sl()),
    )
    ..registerLazySingleton<OpsEventsClient>(
      () => OpsEventsClient(
        config: sl(),
        tokenStore: sl(),
        transport: sseTransport,
      ),
    )
    ..registerLazySingleton<DriversLocationsClient>(
      () => DriversLocationsClient(
        config: sl(),
        tokenStore: sl(),
        transport: webSocketTransport,
      ),
    )
    ..registerLazySingleton<HealthRepository>(
      () => HealthRepository(config: sl(), httpClient: sl()),
    )
    ..registerLazySingleton<ConnectivityBloc>(
      () => ConnectivityBloc(healthRepository: sl(), locationsClient: sl()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(restClient: sl(), tokenStore: sl()),
    )
    ..registerLazySingleton<SessionRepository>(
      () => SessionRepositoryImpl(sl()),
    )
    ..registerLazySingleton<KpiRepository>(() => KpiRepositoryImpl(sl()))
    ..registerLazySingleton<TripRepository>(
      () => TripRepositoryImpl(restClient: sl(), graphQlClient: sl()),
    )
    ..registerLazySingleton<DriverRepository>(
      () => DriverRepositoryImpl(restClient: sl(), graphQlClient: sl()),
    )
    ..registerLazySingleton<AlertRepository>(
      () => AlertRepositoryImpl(restClient: sl(), graphQlClient: sl()),
    )
    ..registerLazySingleton<ChatRepository>(() => ChatRepositoryImpl(sl()))
    ..registerLazySingleton<AdminRepository>(() => AdminRepositoryImpl(sl()))
    ..registerFactory(() => SignIn(sl()))
    ..registerFactory(() => SignOut(sl()))
    ..registerFactory(() => GetMe(sl()))
    ..registerFactory(() => GetKpis(sl()))
    ..registerFactory(() => ListTrips(sl()))
    ..registerFactory(() => GetTrip(sl()))
    ..registerFactory(() => AssignTrip(sl()))
    ..registerFactory(() => CancelTrip(sl()))
    ..registerFactory(() => RefundTrip(sl()))
    ..registerFactory(() => ListAvailableDrivers(sl()))
    ..registerFactory(() => GetDriver(sl()))
    ..registerFactory(() => ListAlerts(sl()))
    ..registerFactory(() => AcknowledgeAlert(sl()))
    ..registerLazySingleton(
      () => SessionBloc(
        signIn: sl(),
        signOut: sl(),
        getMe: sl(),
        tokenStore: sl(),
      ),
    );

  wireSessionExpiry();
  wireRealtimeCleanup();
}

/// Connects REST/GraphQL 401s to a single session-expiration path.
void wireSessionExpiry() {
  void notify() => sl<SessionBloc>().add(const SessionExpired());
  sl<RestClient>().onUnauthorized = notify;
  sl<GraphQlClient>().onUnauthorized = notify;
  sl<DriversLocationsClient>().onUnauthorized = notify;
}

/// Closes SSE/WebSocket when the session is cleared (sign-out or expiry).
void wireRealtimeCleanup() {
  sl<SessionBloc>().addSessionClearedListener(() {
    sl<OpsEventsClient>().disconnect();
    sl<DriversLocationsClient>().disconnect();
    sl<ConnectivityBloc>().add(const ConnectivityStopped());
  });
}

Future<void> resetDependencies() => sl.reset();
