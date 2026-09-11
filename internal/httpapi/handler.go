package httpapi

import (
	"encoding/json"
	"net/http"
	"time"
)

type ProjetoKorpResponse struct {
	Nome    string `json:"nome"`
	Horario string `json:"horario"`
}

func ProjetoKorpHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	response := ProjetoKorpResponse{
		Nome:    "Projeto Korp",
		Horario: time.Now().UTC().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")

	if err := json.NewEncoder(w).Encode(response); err != nil {
		http.Error(w, "internal server error", http.StatusInternalServerError)
	}
}
