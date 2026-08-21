export type UserRole = 'client' | 'designer' | 'complectator' | 'admin';

export type SessionUser = {
  id: string;
  phone: string;
  name: string | null;
  email: string | null;
  role: UserRole;
};

export type ClientScope = 'all' | 'projects' | 'orders' | 'mine';

export type ClientSummary = {
  id: string;
  phone: string;
  name: string | null;
  email: string | null;
  createdAt: string;
  projectsCount: number;
  ordersCount: number;
};

export type ClientProfile = ClientSummary & {
  birthDate: string | null;
  addressesCount: number;
  cartItemsCount: number;
};

export type Address = {
  id: string;
  label: string | null;
  city: string;
  street: string;
  building: string;
  apartment: string | null;
  isDefault: boolean;
};

export type Project = {
  id: string;
  name: string;
  address: string | null;
  status: string;
  statusLabel?: string;
};

export type DocumentItem = {
  id: string;
  projectId: string;
  type: string;
  typeLabel: string;
  name: string;
  size: number | null;
  uploadedAt: string;
};

export type CartItem = {
  id: string;
  quantity: number;
  lockedAt: string | null;
  product: {
    id: string;
    name: string;
    sku: string;
    price: number;
    imageUrl: string | null;
  };
};

export type Cart = {
  id: string;
  projectId?: string;
  items: CartItem[];
  totalAmount?: number;
};

export type Order = {
  id: string;
  status: string;
  statusLabel?: string;
  address: string;
  comment: string | null;
  totalAmount: number;
  createdAt: string;
  items?: Array<{
    id: string;
    quantity: number;
    name?: string;
    product?: { name: string; sku: string };
  }>;
};

export type AuditEntry = {
  id: string;
  action: string;
  actionLabel: string;
  createdAt: string;
  actor: { name: string; phone: string };
};
