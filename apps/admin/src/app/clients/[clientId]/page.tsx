import { ClientDetail } from '@/components/client-detail';

export default async function ClientPage({
  params,
}: {
  params: Promise<{ clientId: string }>;
}) {
  const { clientId } = await params;
  return <ClientDetail clientId={clientId} />;
}
