package router

import (
	"errors"
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
// It uses errors.As to correctly unwrap errors in a chain.
func (h *ProductHandler) CreateProduct(w http.ResponseWriter, r *http.Request) {
	name := r.FormValue("name")
	price := 0.0

	err := h.service.Create(name, price)
	if err == nil {
		w.WriteHeader(http.StatusCreated)
		return
	}

	// errors.As traverses the error chain to find *ValidationError even when wrapped.
	var ve *ValidationError
	if errors.As(err, &ve) {
		http.Error(w, "validation error: "+ve.Field+": "+ve.Message, http.StatusBadRequest)
		return
	}

	http.Error(w, "internal server error", http.StatusInternalServerError)
}
