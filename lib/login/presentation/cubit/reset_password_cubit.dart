import 'package:alzcare/login/data/reset_password_repo.dart';
import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'reset_password_state.dart';

class ResetPasswordCubit extends Cubit<ResetPasswordState> {
  final ResetPasswordRepo resetPasswordRepo;

  ResetPasswordCubit(this.resetPasswordRepo) : super(ResetPasswordInitial());

  Future<void> sendResetEmail({required String email}) async {
    emit(ResetPasswordLoading());
    final res = await resetPasswordRepo.sendResetEmail(email: email);
    res.fold(
          (l) => emit(ResetPasswordFailure(l)),
          (_) => emit(ResetPasswordSuccess()),
    );
  }

  Future<void> forceResetWithServiceRole({
    required String email,
    required String newPassword,
  }) async {
    emit(ResetPasswordLoading());
    final res = await resetPasswordRepo.forceResetWithServiceRole(
      email: email,
      newPassword: newPassword,
    );
    res.fold(
          (l) => emit(ResetPasswordFailure(l)),
          (_) => emit(ResetPasswordSuccess()),
    );
  }
}

