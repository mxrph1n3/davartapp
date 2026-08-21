import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../../core/widgets/state_views.dart';
import '../../commerce/data/commerce_models.dart';
import '../data/staff_repository.dart';

final _priceFormat = NumberFormat.currency(locale: 'ru_RU', symbol: '₽');
final _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

final staffClientOrderProvider = FutureProvider.autoDispose
    .family<Order, ({String clientId, String orderId})>((ref, ids) {
  return ref
      .watch(staffRepositoryProvider)
      .getOrder(ids.clientId, ids.orderId);
});

class StaffOrderDetailScreen extends ConsumerWidget {
  const StaffOrderDetailScreen({
    super.key,
    required this.clientId,
    required this.orderId,
  });

  final String clientId;
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(
      staffClientOrderProvider((clientId: clientId, orderId: orderId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заказ клиента'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => popOrGo(
            context,
            AppRoutes.staffClientProfile(clientId),
          ),
        ),
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Не удалось загрузить заказ',
          onRetry: () => ref.invalidate(
            staffClientOrderProvider(
              (clientId: clientId, orderId: orderId),
            ),
          ),
        ),
        data: (order) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              StatusBadge(
                label: order.statusLabel,
                highlighted: order.status == 'created',
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '№ ${order.id.substring(0, 8)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(_dateFormat.format(order.createdAt.toLocal())),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Адрес',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(order.address),
              if (order.comment != null && order.comment!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Комментарий',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(order.comment!),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Состав',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              ...order.items.map(
                (item) => ListItem(
                  title: item.name,
                  subtitle: '${item.quantity} × ${_priceFormat.format(item.price)}',
                  showChevron: false,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Итого: ${_priceFormat.format(order.totalAmount)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}
