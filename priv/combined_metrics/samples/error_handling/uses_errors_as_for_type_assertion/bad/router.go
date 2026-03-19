package router

import (
	"net/http"
)

// ValidationError represents a field-level validation failure.
type ValidationError struct {
	Field   string
	Message string
}

func (e *ValidationError) Error() string {
	return e.Field + ": " + e.Message
}

type ProductHandler struct {
	service ProductService
}

type ProductService interface {
	Create(name string, price float64) error
}

// CreateProduct handles product creation and maps ValidationError to 400.
// It uses a direct type assertion, which fails silently when the error is wrapped.
func (h *ProductHandler) CreateProduct(w http.ResponseWriter, r *http.Request) {
	name := r.FormValue("name")
	price := 0.0

	err := h.service.Create(name, price)
	if err == nil {
		w.WriteHeader(http.StatusCreated)
		return
	}

	// Direct type assertion fails when the error is wrapped with fmt.Errorf("%w", ve).
	if ve, ok := err.(*ValidationError); ok {
		http.Error(w, "validation error: "+ve.Field+": "+ve.Message, http.StatusBadRequest)
		return
	}

	http.Error(w, "internal server error", http.StatusInternalServerError)
}
