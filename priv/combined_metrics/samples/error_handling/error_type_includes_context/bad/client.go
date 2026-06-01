package client

import (
	"errors"
	"fmt"
	"net/http"
)

// APIError carries no useful context about what failed or where.
type APIError struct {
	Message string
}

func (e *APIError) Error() string {
	return e.Message
}

type PaymentClient struct {
	base   string
	client *http.Client
}

func NewPaymentClient(base string) *PaymentClient {
	return &PaymentClient{base: base, client: &http.Client{}}
}

func (c *PaymentClient) Charge(orderID string, amountCents int) error {
	url := fmt.Sprintf("%s/orders/%s/charge", c.base, orderID)
	req, err := http.NewRequest(http.MethodPost, url, nil)
	if err != nil {
		// wraps nothing; caller cannot recover the original error or know the URL
		return &APIError{Message: "request failed"}
	}

	resp, err := c.client.Do(req)
	if err != nil {
		// loses the original transport error entirely
		return errors.New("request failed")
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		// no operation, resource, or status code included
		return &APIError{Message: "unexpected response"}
	}
	return nil
}
