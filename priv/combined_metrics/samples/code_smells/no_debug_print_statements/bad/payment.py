class Payment:
    def charge(self, user, amount, card):
        print("charging user:", user.id)
        print("card details:", card)
        print("amount:", amount)

        validated = self._validate_card(card)
        if not validated:
            print("card validation failed")
            return None

        print("card validated successfully")
        result = self._call_gateway(validated, amount)
        print("gateway result:", result)
        return result

    def refund(self, transaction_id, amount):
        print("starting refund for transaction:", transaction_id)
        transaction = self._fetch_transaction(transaction_id)
        print("found transaction:", transaction)

        if transaction["amount"] < amount:
            print("refund amount exceeds original")
            return {"error": "exceeds_original"}

        print("processing refund of", amount)
        result = self._call_refund_api(transaction, amount)
        print("refund result:", result)
        return result

    def calculate_fee(self, amount, method):
        print("fee calc input:", amount, method)
        if method == "credit_card":
            fee = amount * 0.029 + 0.30
        elif method == "debit_card":
            fee = amount * 0.015
        else:
            fee = amount * 0.035
        print("calculated fee:", fee)
        return fee

    def _validate_card(self, card):
        return card

    def _call_gateway(self, _card, _amount):
        return {"transaction_id": "txn_123"}

    def _fetch_transaction(self, _id):
        return {"amount": 100.0}

    def _call_refund_api(self, _transaction, _amount):
        return {"status": "refunded"}
