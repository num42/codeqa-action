package client

import (
	"fmt"
	"net/http"
)

// APIError captures the HTTP operation, the target resource, the HTTP status
// code, and the underlying transport error when one occurs.
type APIError struct {
	Method   string
	Resource string
	Status   int
	Err      error
}

func (e *APIError) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("%s %s: status %d: %v", e.Method, e.Resource, e.Status, e.Err)
	}
	return fmt.Sprintf("%s %s: status %d", e.Method, e.Resource, e.Status)
}

func (e *APIError) Unwrap() error { return e.Err }

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
		return &APIError{Method: "POST", Resource: url, Err: err}
	}

	resp, err := c.client.Do(req)
	if err != nil {
		return &APIError{Method: "POST", Resource: url, Err: err}
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return &APIError{
			Method:   "POST",
			Resource: url,
			Status:   resp.StatusCode,
		}
	}
	return nil
}
