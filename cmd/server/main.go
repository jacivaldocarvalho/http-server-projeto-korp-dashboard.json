package main

import (
	"log"
	"net/http"
	"time"

	"github.com/jacivaldocarvalho/http-server-projeto-korp-dashboard.json/internal/httpapi"
	"github.com/jacivaldocarvalho/http-server-projeto-korp-dashboard.json/internal/observability"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	registry := prometheus.NewRegistry()

	registry.MustRegister(
		prometheus.NewGoCollector(),
		prometheus.NewProcessCollector(
			prometheus.ProcessCollectorOpts{},
		),
	)

	metrics := observability.NewMetrics(registry)

	mux := http.NewServeMux()

	mux.Handle(
		"/projeto-korp",
		metrics.Instrument(
			"/projeto-korp",
			http.HandlerFunc(httpapi.ProjetoKorpHandler),
		),
	)

	mux.Handle(
		"/metrics",
		promhttp.HandlerFor(
			registry,
			promhttp.HandlerOpts{},
		),
	)

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
