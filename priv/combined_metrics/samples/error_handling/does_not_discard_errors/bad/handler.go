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
	// error from Decode is discarded
	_ = json.NewDecoder(r.Body).Decode(&req)

	// error from PlaceOrder is discarded
	orderID, _ := h.service.PlaceOrder(req)

	// error from NotifyUser is discarded
	_ = h.service.NotifyUser(req.UserID, orderID)

	resp := OrderResponse{OrderID: orderID, Status: "confirmed"}
	w.Header().Set("Content-Type", "application/json")
	// error from Encode is discarded
	_ = json.NewEncoder(w).Encode(resp)
}
