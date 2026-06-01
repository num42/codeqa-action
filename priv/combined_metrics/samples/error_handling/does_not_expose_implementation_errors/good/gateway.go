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
// Internal HTTP and JSON errors are wrapped with %v to avoid leaking
// implementation details to callers above this abstraction layer.
func (g *ShippingGateway) TrackShipment(ctx context.Context, trackingID string) (*ShipmentStatus, error) {
	url := fmt.Sprintf("%s/shipments/%s", g.base, trackingID)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		// %v instead of %w: callers should not depend on http.Request internals.
		return nil, fmt.Errorf("track shipment %q: build request: %v", trackingID, err)
	}

	resp, err := g.client.Do(req)
	if err != nil {
		// %v prevents leaking net/url or transport error types.
		return nil, fmt.Errorf("track shipment %q: call carrier api: %v", trackingID, err)
	}
	defer resp.Body.Close()

	var status ShipmentStatus
	if err := json.NewDecoder(resp.Body).Decode(&status); err != nil {
		// %v hides JSON parsing internals from callers.
		return nil, fmt.Errorf("track shipment %q: decode response: %v", trackingID, err)
	}
	return &status, nil
}
