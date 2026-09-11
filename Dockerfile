# syntax=docker/dockerfile:1.7

FROM golang:1.22.2-alpine AS builder

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/http-server-projeto-korp \
    ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /app

COPY --from=builder /out/http-server-projeto-korp /app/http-server-projeto-korp

USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["/app/http-server-projeto-korp"]
