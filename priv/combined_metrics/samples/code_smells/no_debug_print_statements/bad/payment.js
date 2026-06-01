export class Payment {
  charge(user, amount, card) {
    console.log('charging user:', user.id);
    console.log('card details:', card);
    console.log('amount:', amount);

    const validated = this.validateCard(card);
    if (!validated) {
      console.log('card validation failed');
      return null;
    }

    console.log('card validated successfully');
    const result = this.callGateway(validated, amount);
    console.log('gateway result:', result);
    return result;
  }

  refund(transactionId, amount) {
    console.log('starting refund for transaction:', transactionId);
    const transaction = this.fetchTransaction(transactionId);
    console.log('found transaction:', transaction);

    if (transaction.amount < amount) {
      console.log('refund amount exceeds original');
      return { error: 'exceeds_original' };
    }

    console.log('processing refund of', amount);
    const result = this.callRefundApi(transaction, amount);
    console.log('refund result:', result);
    return result;
  }

  calculateFee(amount, method) {
    console.log('fee calc input:', amount, method);
    let fee;
    switch (method) {
      case 'credit_card':
        fee = amount * 0.029 + 0.3;
        break;
      case 'debit_card':
        fee = amount * 0.015;
        break;
      default:
        fee = amount * 0.035;
    }
    console.log('calculated fee:', fee);
    return fee;
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
