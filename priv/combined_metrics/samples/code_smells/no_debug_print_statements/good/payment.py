import logging

logger = logging.getLogger(__name__)


class Payment:
    def charge(self, user, amount, card):
        validated = self._validate_card(card)
        if not validated:
            logger.warning("card validation failed for user %s", user.id)
            return None

        result = self._call_gateway(validated, amount)
        logger.info("payment charged user=%s amount=%s", user.id, amount)
        return result

    def refund(self, transaction_id, amount):
        transaction = self._fetch_transaction(transaction_id)
        if not transaction:
            return {"error": "not_found"}

        if transaction["amount"] < amount:
            return {"error": "exceeds_original"}

        result = self._call_refund_api(transaction, amount)
        logger.info("refund processed tx=%s amount=%s", transaction_id, amount)
        return result

    def calculate_fee(self, amount, method):
        if method == "credit_card":
            return amount * 0.029 + 0.30
        if method == "debit_card":
            return amount * 0.015
        if method == "bank_transfer":
            return 0.25
        return amount * 0.035

    def _validate_card(self, card):
        return card

    def _call_gateway(self, _card, _amount):
        return {"transaction_id": "txn_123"}

    def _fetch_transaction(self, _id):
        return {"amount": 100.0}

    def _call_refund_api(self, _transaction, _amount):
        return {"status": "refunded"}
