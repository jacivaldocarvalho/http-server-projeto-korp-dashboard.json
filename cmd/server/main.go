package main

import (
	"log"
	"net/http"
	"time"

	"github.com/jacivaldocarvalho/http-server-projeto-korp-dashboard.json/internal/httpapi"
)

func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("/projeto-korp", httpapi.ProjetoKorpHandler)

	server := &http.Server{
		Addr:              ":8080",
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	log.Println("Show! http-server-projeto-korp iniciado na porta 8080")

	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("erro ao iniciar servidor: %v", err)
	}
}
