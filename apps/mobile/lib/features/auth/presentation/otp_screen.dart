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
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCode?.trim() ?? '';
    _suppressAutoVerify = true;
    _controller = TextEditingController(text: initial);
    _startTimer();
    if (initial.length == 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _suppressAutoVerify = false;
        _verify();
      });
    } else {
      _suppressAutoVerify = false;
    }
  }

  Future<void> _leaveOtpIfAuthenticated() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || !mounted || _leavingOtp) return;
    _leavingOtp = true;
    await maybeAskDisplayName(context, ref);
    if (!mounted) return;
    if (isEmbeddedLogin(GoRouterState.of(context))) {
      finishEmbeddedLogin(context);
      return;
    }
    context.go(
      AppRoutes.homeForRole(auth.user?.role ?? UserRole.client),
    );
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
    if (widget.phone.isEmpty) {
      if (mounted) context.go(AppRoutes.phone);
      return;
    }

    final code = _controller.text.trim();
    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Код должен содержать 4 цифры')),
      );
      return;
    }

    if (_verifyInFlight) return;
    _verifyInFlight = true;
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).verifyOtp(phone: widget.phone, code: code);
      if (!mounted) return;
      _leaveOtpIfAuthenticated();
    } on Exception catch (error) {
      if (mounted) {
        // Session may already be valid from a parallel auto-submit.
        if (ref.read(authProvider).isAuthenticated) {
          _leaveOtpIfAuthenticated();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      _verifyInFlight = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    try {
      final debugCode =
          await ref.read(authProvider.notifier).sendOtp(widget.phone);
      _startTimer();
      if (!mounted) return;
      if (debugCode != null && debugCode.isNotEmpty) {
        _suppressAutoVerify = true;
        _controller.text = debugCode;
        _suppressAutoVerify = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mock-код: $debugCode')),
        );
        await _verify();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Код отправлен повторно')),
        );
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
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
              Text('Код из SMS', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32)),
              const SizedBox(height: AppSpacing.sm),
              Text('Отправлен на ${widget.phone}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.xl),
              AppInput(
                controller: _controller,
                hintText: '0000',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w600),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onChanged: (value) {
                  if (_suppressAutoVerify || _isLoading || _verifyInFlight) {
                    return;
                  }
                  if (value.length == 4) _verify();
                },
              ),
              const SizedBox(height: AppSpacing.md),
              GhostButton(
                label: _secondsLeft > 0
                    ? 'Отправить повторно через $_secondsLeft сек'
                    : 'Отправить код повторно',
                onPressed: _secondsLeft > 0 ? null : _resend,
              ),
              const Spacer(),
              PrimaryButton(label: 'Войти', isLoading: _isLoading, onPressed: _verify),
            ],
          ),
        ),
      ),
    );
  }
}
