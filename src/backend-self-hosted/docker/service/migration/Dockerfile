# Stage 1: Build the Go application
# Use a specific Go version for reproducible builds (latest stable as of writing)
FROM golang:1.26-alpine AS builder

# Set environment variables for static linking and module support
ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

WORKDIR /app

# Copy go.mod and go.sum first to leverage Docker caching
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source code
# Use .dockerignore to exclude unnecessary files (e.g., .git, node_modules, etc.)
COPY . .

# Build the binary with optimizations: strip debug info and disable symbol table
RUN go build -ldflags="-s -w" -o main .

# Stage 2: Create the final lightweight image
# Use a minimal Alpine base with a specific version for security and stability
FROM alpine:latest

# Copy the compiled binary from the builder stage
COPY --from=builder /app/main /app/main

# Set working directory for the application
WORKDIR /app

# Copy any required scripts, preserving executable permissions
COPY scripts/* ./scripts/

# Run the binary
CMD ["./main"]