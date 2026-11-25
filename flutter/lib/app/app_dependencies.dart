import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/storage/preferences_store.dart';
import '../data/datasources/supabase_auth_data_source.dart';
import '../data/datasources/image_picker_profile_photo_data_source.dart';
import '../data/repositories/supabase_authentication_repository.dart';
import '../data/repositories/dashboard_repository.dart';
import '../data/repositories/image_picker_profile_photo_repository.dart';
import '../data/repositories/android_permission_repository.dart';
import '../features/authentication/presenters/auth_presenter.dart';
import '../features/dashboard/presenters/dashboard_presenter.dart';
import '../features/permissions/presenters/permission_presenter.dart';

class AppDependencies {
  const AppDependencies({
    required this.supabaseConfigured,
    this.authPresenter,
    this.dashboardPresenter,
    this.permissionPresenter,
  });

  factory AppDependencies.fromSupabase(SupabaseClient client) {
    final authenticationRepository = SupabaseAuthenticationRepository(
      SupabaseAuthDataSource(client),
    );
    return AppDependencies(
      supabaseConfigured: true,
      authPresenter: AuthPresenter(authenticationRepository),
      dashboardPresenter: DashboardPresenter(
        SupabaseDashboardRepository(client),
        preferencesStore: const SharedPreferencesStore(),
        profilePhotoPickerRepository: ImagePickerProfilePhotoRepository(
          ImagePickerProfilePhotoDataSource(),
        ),
      ),
      permissionPresenter: PermissionPresenter(
        const AndroidPermissionRepository(),
      ),
    );
  }

  final bool supabaseConfigured;
  final AuthPresenter? authPresenter;
  final DashboardPresenter? dashboardPresenter;
  final PermissionPresenter? permissionPresenter;
}
