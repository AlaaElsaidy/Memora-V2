import 'package:alzcare/core/supabase/auth-service.dart';
import 'package:alzcare/core/supabase/supabase-config.dart';
import 'package:alzcare/core/supabase/supabase-error-handler.dart';
import 'package:dartz/dartz.dart';

class ResetPasswordRepo {
  final AuthService authService;

  ResetPasswordRepo(this.authService);

  Future<Either<String, void>> sendResetEmail({required String email}) async {
    try {
      await authService.resetPassword(email);
      return const Right(null);
    } catch (error) {
      return Left(SupabaseErrorHandler.handleError(error));
    }
  }

  /// DEV/TEST ONLY: uses service role key (if provided) to set a new password directly.
  Future<Either<String, void>> forceResetWithServiceRole({
    required String email,
    required String newPassword,
  }) async {
    try {
      final serviceClient = SupabaseConfig.serviceClient;
      if (serviceClient == null) {
        return const Left(
            'Missing SUPABASE_SERVICE_KEY. Provide it via --dart-define for dev.');
      }

      await authService.forceChangePasswordWithServiceRole(
        email: email,
        newPassword: newPassword,
        serviceClient: serviceClient,
      );
      return const Right(null);
    } catch (error) {
      return Left(SupabaseErrorHandler.handleError(error));
    }
  }
}

