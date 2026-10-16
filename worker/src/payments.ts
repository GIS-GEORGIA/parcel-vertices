export interface OrderInfo {
  id: string;
  amountTetri: number;
  currency: string;
  productId: string;
}

/**
 * Add a real gateway (Flitt, Keepz, ...) by implementing this interface and registering it in getProvider().
 * Rule: never trust the redirect back to the app. Only verifyWebhook() may mark an order paid.
 */
export interface PaymentProvider {
  name: string;
  createCheckout(order: OrderInfo, env: Env): Promise<{ checkoutUrl: string; providerRef: string }>;
  /** Validate the gateway's signature and return which order was paid, or null if invalid/irrelevant. */
  verifyWebhook(request: Request, env: Env): Promise<{ orderId: string; paid: boolean } | null>;
}

/** Local-only provider: checkout page served by this Worker. Disabled unless PAYMENT_PROVIDER=mock. */
const mock: PaymentProvider = {
  name: 'mock',
  async createCheckout(order, env) {
    return { checkoutUrl: `${env.PUBLIC_BASE_URL}/mock/pay/${order.id}`, providerRef: `mock_${order.id}` };
  },
  async verifyWebhook() {
    return null;
  },
};

/** Used until a real gateway is wired: orders are refused with a clear error. */
export class PaymentsUnavailable extends Error {}

const disabled: PaymentProvider = {
  name: 'disabled',
  async createCheckout() {
    throw new PaymentsUnavailable('payments_unavailable');
  },
  async verifyWebhook() {
    return null;
  },
};

export function getProvider(env: Env): PaymentProvider {
  switch (env.PAYMENT_PROVIDER) {
    case 'disabled':
      return disabled;
    case 'mock':
      return mock;
    default:
      throw new Error(`Unknown PAYMENT_PROVIDER: ${env.PAYMENT_PROVIDER}`);
  }
}
