package handler

import (
	"encoding/json"
	"log"
	"net/http"
)

type OrderRequest struct {
	UserID    string  `json:"user_id"`
	ProductID string  `json:"product_id"`
	Quantity  int     `json:"quantity"`
	Price     float64 `json:"price"`
}

type OrderResponse struct {
	OrderID string `json:"order_id"`
	Status  string `json:"status"`
}

type OrderService interface {
	PlaceOrder(req OrderRequest) (string, error)
	NotifyUser(userID, orderID string) error
}

type OrderHandler struct {
	service OrderService
	logger  *log.Logger
}

func NewOrderHandler(service OrderService, logger *log.Logger) *OrderHandler {
	return &OrderHandler{service: service, logger: logger}
}

func (h *OrderHandler) PlaceOrder(w http.ResponseWriter, r *http.Request) {
	var req OrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.logger.Printf("failed to decode request: %v", err)
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	orderID, err := h.service.PlaceOrder(req)
	if err != nil {
		h.logger.Printf("failed to place order for user %s: %v", req.UserID, err)
		http.Error(w, "failed to place order", http.StatusInternalServerError)
		return
	}

	if err := h.service.NotifyUser(req.UserID, orderID); err != nil {
		h.logger.Printf("failed to notify user %s for order %s: %v", req.UserID, orderID, err)
		// notification failure is non-fatal; continue
	}

	resp := OrderResponse{OrderID: orderID, Status: "confirmed"}
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		h.logger.Printf("failed to encode response: %v", err)
	}
}
