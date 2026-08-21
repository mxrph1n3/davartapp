export default function ClientsIndexPage() {
  return (
    <div className="flex flex-1 items-center justify-center p-10 text-center">
      <div>
        <p className="font-[family-name:var(--font-fraunces)] text-2xl">
          Клиент
        </p>
        <p className="mt-2 max-w-sm text-sm text-[var(--muted)]">
          Выберите карточку слева — проекты, документы, корзина и заказы
          откроются здесь.
        </p>
      </div>
    </div>
  );
}
