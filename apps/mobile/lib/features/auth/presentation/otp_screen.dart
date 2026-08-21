import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import 'auth_notifier.dart';
import 'require_login.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft == 0) {
        timer.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
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

    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).verifyOtp(phone: widget.phone, code: code);
      if (!mounted) return;
      if (isEmbeddedLogin(GoRouterState.of(context))) {
        finishEmbeddedLogin(context);
      } else {
        context.go(AppRoutes.catalog);
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    try {
      await ref.read(authProvider.notifier).sendOtp(widget.phone);
      _startTimer();
      if (mounted) {
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
                  if (value.length == 4 && !_isLoading) {
                    _verify();
                  }
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
