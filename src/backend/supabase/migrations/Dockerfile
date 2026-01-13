# Stage 1: Build the Go app
FROM golang:1.25-alpine AS builder

# Set environment variables for Go build
ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

WORKDIR /app

# Install Go dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy the source code and build
COPY . .
RUN go build -o main .

# Stage 2: Final image
FROM alpine:3.19

# Copy the built Go binary from the builder stage
COPY --from=builder /app/main /app/main

# Set working directory and permissions
WORKDIR /app

# Run the binary
CMD ["./main"]