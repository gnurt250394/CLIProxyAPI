FROM golang:1.24-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY . .

ARG VERSION=dev
ARG COMMIT=none
ARG BUILD_DATE=unknown

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w -X 'main.Version=${VERSION}' -X 'main.Commit=${COMMIT}' -X 'main.BuildDate=${BUILD_DATE}'" -o ./CLIProxyAPI ./cmd/server/

FROM alpine:3.22.0

RUN apk add --no-cache tzdata

RUN mkdir /CLIProxyAPI

COPY --from=builder ./app/CLIProxyAPI /CLIProxyAPI/CLIProxyAPI

# Copy config.example.yaml from builder stage
COPY --from=builder ./app/config.example.yaml /CLIProxyAPI/config.example.yaml

# Always create config.yaml from example to ensure the app has a config file when deployed to Koyeb
# This is critical because Koyeb doesn't allow running commands after deployment
# Users can override configuration via environment variables or the management API after deployment
RUN if [ -f /CLIProxyAPI/config.example.yaml ]; then \
        cp /CLIProxyAPI/config.example.yaml /CLIProxyAPI/config.yaml && \
        echo "Created config.yaml from config.example.yaml"; \
    else \
        echo "ERROR: config.example.yaml not found!" && exit 1; \
    fi && \
    ls -lh /CLIProxyAPI/config*.yaml

WORKDIR /CLIProxyAPI

EXPOSE 8317

ENV TZ=Asia/Shanghai

RUN cp /usr/share/zoneinfo/${TZ} /etc/localtime && echo "${TZ}" > /etc/timezone

CMD ["./CLIProxyAPI"]