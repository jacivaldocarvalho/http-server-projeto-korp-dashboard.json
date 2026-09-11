package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestProjetoKorpHandler(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/projeto-korp", nil)
	rec := httptest.NewRecorder()

	ProjetoKorpHandler(rec, req)

	res := rec.Result()
	defer res.Body.Close()

	if res.StatusCode != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, res.StatusCode)
	}

	if contentType := res.Header.Get("Content-Type"); contentType != "application/json" {
		t.Fatalf("expected Content-Type application/json, got %s", contentType)
	}

	var body ProjetoKorpResponse

	if err := json.NewDecoder(res.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response body: %v", err)
	}

	if body.Nome != "Projeto Korp" {
		t.Errorf("expected nome %q, got %q", "Projeto Korp", body.Nome)
	}

	if body.Horario == "" {
		t.Fatal("expected horario to be populated")
	}

	parsedTime, err := time.Parse(time.RFC3339, body.Horario)
	if err != nil {
		t.Fatalf("expected horario in RFC3339 format, got %q", body.Horario)
	}

	if parsedTime.Location() != time.UTC {
		t.Errorf("expected horario in UTC, got %s", parsedTime.Location())
	}
}

func TestProjetoKorpHandlerMethodNotAllowed(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/projeto-korp", nil)
	rec := httptest.NewRecorder()

	ProjetoKorpHandler(rec, req)

	res := rec.Result()
	defer res.Body.Close()

	if res.StatusCode != http.StatusMethodNotAllowed {
		t.Fatalf(
			"expected status %d, got %d",
			http.StatusMethodNotAllowed,
			res.StatusCode,
		)
	}
}
