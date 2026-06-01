import { logger } from './logger.js';

export class Payment {
  charge(user, amount, card) {
    const validated = this.validateCard(card);
    if (!validated) {
      logger.warn('card validation failed', { userId: user.id });
      return null;
    }

    const result = this.callGateway(validated, amount);
    logger.info('payment charged', { userId: user.id, amount });
    return result;
  }

  refund(transactionId, amount) {
    const transaction = this.fetchTransaction(transactionId);
    if (!transaction) {
      return { error: 'not_found' };
    }

    if (transaction.amount < amount) {
      return { error: 'exceeds_original' };
    }

    const result = this.callRefundApi(transaction, amount);
    logger.info('refund processed', { transactionId, amount });
    return result;
  }

  calculateFee(amount, method) {
    switch (method) {
      case 'credit_card':
        return amount * 0.029 + 0.3;
      case 'debit_card':
        return amount * 0.015;
      case 'bank_transfer':
        return 0.25;
      default:
        return amount * 0.035;
    }
  }

  validateCard(card) {
    return card;
  }

  callGateway(_card, _amount) {
    return { transactionId: 'txn_123' };
  }

  fetchTransaction(_id) {
    return { amount: 100.0 };
  }

  callRefundApi(_transaction, _amount) {
    return { status: 'refunded' };
  }
}
