import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../data/auth_repository.dart';
import 'ask_display_name.dart';
import 'auth_notifier.dart';
import 'require_login.dart';

const _otpLength = 4;

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone, this.initialCode});

  final String phone;
  final String? initialCode;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  late final TextEditingController _controller;
  bool _isLoading = false;
  bool _verifyInFlight = false;
  bool _suppressAutoVerify = false;
  bool _leavingOtp = false;
  bool _smsSending = false;
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCode?.trim() ?? '';
    _suppressAutoVerify = true;
    _controller = TextEditingController(text: initial);
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Route may remount after auth refresh — leave immediately if already in.
      if (ref.read(authProvider).isAuthenticated) {
        _leaveOtpIfAuthenticated();
        return;
      }
      if (initial.length == _otpLength) {
        _suppressAutoVerify = false;
        _verify();
      } else {
        _suppressAutoVerify = false;
      }
    });
  }

  Future<void> _leaveOtpIfAuthenticated() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || !mounted || _leavingOtp) return;
    _leavingOtp = true;
    if (mounted) setState(() {});

    final embedded = isEmbeddedLogin(GoRouterState.of(context));
    final home = AppRoutes.homeForRole(auth.user?.role ?? UserRole.client);

    // Leave OTP first so the user never sees a second «code» screen.
    if (embedded) {
      finishEmbeddedLogin(context);
    } else if (mounted) {
      context.go(home);
    }

    // Ask for display name on the destination route.
    await Future<void>.delayed(Duration.zero);
    final navContext = rootNavigatorKey.currentContext;
    if (navContext != null && navContext.mounted) {
      await maybeAskDisplayName(navContext, ref);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft == 0) {
        timer.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
    if (mounted) setState(() {});
  }

  Future<void> _verify() async {
    if (_leavingOtp) return;
    if (widget.phone.isEmpty) {
      if (mounted) context.go(AppRoutes.phone);
      return;
    }

    final code = _controller.text.trim();
    if (code.length != _otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Код должен содержать $_otpLength цифры')),
      );
      return;
    }

    if (_verifyInFlight) return;
    _verifyInFlight = true;
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).verifyOtp(
            phone: widget.phone,
            code: code,
          );
      if (!mounted) return;
      await _leaveOtpIfAuthenticated();
    } on Exception catch (error) {
      if (mounted) {
        if (ref.read(authProvider).isAuthenticated) {
          await _leaveOtpIfAuthenticated();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      _verifyInFlight = false;
      if (mounted && !_leavingOtp) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend({String channel = 'sms'}) async {
    if (_leavingOtp || ref.read(authProvider).isAuthenticated) return;
    if (_secondsLeft > 0 || _smsSending) return;

    setState(() => _smsSending = true);

    try {
      final debugCode = await ref.read(authProvider.notifier).sendOtp(
            widget.phone,
            channel: channel,
          );
      if (!mounted || _leavingOtp || ref.read(authProvider).isAuthenticated) {
        return;
      }
      _startTimer();
      if (debugCode != null && debugCode.isNotEmpty) {
        _suppressAutoVerify = true;
        _controller.text = debugCode;
        _suppressAutoVerify = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mock-код: $debugCode')),
        );
        await _verify();
      } else {
        _controller.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Код отправлен по SMS'),
          ),
        );
      }
    } on Exception catch (error) {
      if (mounted && !_leavingOtp && !ref.read(authProvider).isAuthenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _smsSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.isAuthenticated && previous?.isAuthenticated != true) {
        _leaveOtpIfAuthenticated();
      }
    });

    final authenticated = ref.watch(authProvider).isAuthenticated;
    if (_leavingOtp || authenticated) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppBackButton(
          fallback: isEmbeddedLogin(GoRouterState.of(context))
              ? loginPhonePath
              : AppRoutes.phone,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Код из SMS',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 32),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Отправлен на ${widget.phone}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppInput(
                controller: _controller,
                hintText: '0000',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  letterSpacing: 8,
                  fontWeight: FontWeight.w600,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_otpLength),
                ],
                onChanged: (value) {
                  if (_suppressAutoVerify ||
                      _isLoading ||
                      _verifyInFlight ||
                      _leavingOtp) {
                    return;
                  }
                  if (value.length == _otpLength) _verify();
                },
              ),
              const SizedBox(height: AppSpacing.md),
              GhostButton(
                label: _secondsLeft > 0
                    ? 'Отправить повторно через $_secondsLeft сек'
                    : 'Отправить код повторно',
                onPressed: _secondsLeft > 0 || _smsSending
                    ? null
                    : () => _resend(),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Войти',
                isLoading: _isLoading,
                onPressed: _verify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
