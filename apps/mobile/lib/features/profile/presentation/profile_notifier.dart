import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_notifier.dart';
import '../data/profile_repository.dart';

final profileProvider = FutureProvider.autoDispose<UserProfile>((ref) {
  if (!ref.watch(authProvider).isAuthenticated) {
    throw StateError('Not signed in');
  }
  return ref.watch(profileRepositoryProvider).getMe();
});

final addressesProvider = FutureProvider.autoDispose<List<UserAddress>>((ref) {
  if (!ref.watch(authProvider).isAuthenticated) return [];
  return ref.watch(profileRepositoryProvider).getAddresses();
});

final faqProvider = FutureProvider.autoDispose<List<FaqItem>>((ref) {
  return ref.watch(profileRepositoryProvider).getFaq();
});

class ProfileActions {
  ProfileActions(this._ref);

  final Ref _ref;

  ProfileRepository get _repository => _ref.read(profileRepositoryProvider);

  Future<UserProfile> updateProfile({
    String? name,
    String? email,
    bool? notificationsEnabled,
  }) async {
    final profile = await _repository.updateProfile(
      name: name,
      email: email,
      notificationsEnabled: notificationsEnabled,
    );
    _ref.read(authProvider.notifier).updateUserProfile(profile);
    _ref.invalidate(profileProvider);
    return profile;
  }

  Future<void> openSupportChat() async {
    await _repository.getSupportChat();
  }
}

final profileActionsProvider = Provider<ProfileActions>((ref) {
  return ProfileActions(ref);
});
