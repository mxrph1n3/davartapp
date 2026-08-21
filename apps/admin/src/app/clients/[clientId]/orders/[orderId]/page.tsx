import { ClientDetail } from '@/components/client-detail';

export default async function ClientOrderPage({
  params,
}: {
  params: Promise<{ clientId: string; orderId: string }>;
}) {
  const { clientId, orderId } = await params;
  return <ClientDetail clientId={clientId} highlightOrderId={orderId} />;
}
