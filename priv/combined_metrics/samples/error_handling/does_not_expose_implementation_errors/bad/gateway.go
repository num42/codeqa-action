package gateway

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
)

// ShipmentStatus is returned by the shipping gateway.
type ShipmentStatus struct {
	TrackingID string
	State      string
}

// ShippingGateway calls an external carrier API.
type ShippingGateway struct {
	base   string
	client *http.Client
}

func New(base string) *ShippingGateway {
	return &ShippingGateway{base: base, client: &http.Client{}}
}

// TrackShipment retrieves the current status of a shipment.
// Using %w exposes internal http, net/url, and json error types to callers,
// leaking implementation details across the abstraction boundary.
func (g *ShippingGateway) TrackShipment(ctx context.Context, trackingID string) (*ShipmentStatus, error) {
	url := fmt.Sprintf("%s/shipments/%s", g.base, trackingID)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		// %w leaks *url.Error and http internals to callers.
		return nil, fmt.Errorf("track shipment %q: build request: %w", trackingID, err)
	}

	resp, err := g.client.Do(req)
	if err != nil {
		// %w propagates net/http transport types; callers now depend on them.
		return nil, fmt.Errorf("track shipment %q: call carrier api: %w", trackingID, err)
	}
	defer resp.Body.Close()

	var status ShipmentStatus
	if err := json.NewDecoder(resp.Body).Decode(&status); err != nil {
		// %w exposes *json.SyntaxError / *json.UnmarshalTypeError to callers.
		return nil, fmt.Errorf("track shipment %q: decode response: %w", trackingID, err)
	}
	return &status, nil
}
