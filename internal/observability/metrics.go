package observability

import (
	"net/http"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

type Metrics struct {
	requestsTotal   *prometheus.CounterVec
	requestDuration *prometheus.HistogramVec
}

func NewMetrics(reg prometheus.Registerer) *Metrics {
	metrics := &Metrics{
		requestsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Namespace: "korp",
				Subsystem: "http",
				Name:      "requests_total",
				Help:      "Total number of HTTP requests processed by the application.",
			},
			[]string{"method", "endpoint", "status"},
		),

		requestDuration: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Namespace: "korp",
				Subsystem: "http",
				Name:      "request_duration_seconds",
				Help:      "HTTP request duration in seconds.",
				Buckets:   prometheus.DefBuckets,
			},
			[]string{"method", "endpoint"},
		),
	}

	reg.MustRegister(
		metrics.requestsTotal,
		metrics.requestDuration,
	)

	return metrics
}

func (m *Metrics) Instrument(endpoint string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		recorder := &statusRecorder{
			ResponseWriter: w,
			statusCode:     http.StatusOK,
		}

		next.ServeHTTP(recorder, r)

		m.requestsTotal.
			WithLabelValues(
				r.Method,
				endpoint,
				strconv.Itoa(recorder.statusCode),
			).
			Inc()

		m.requestDuration.
			WithLabelValues(r.Method, endpoint).
			Observe(time.Since(start).Seconds())
	})
}

type statusRecorder struct {
	http.ResponseWriter
	statusCode int
}

func (r *statusRecorder) WriteHeader(statusCode int) {
	r.statusCode = statusCode
	r.ResponseWriter.WriteHeader(statusCode)
}
