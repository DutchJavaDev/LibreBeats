# Stage 1: Builder
FROM golang:1.26-alpine AS builder
WORKDIR /app

# Copy go mod files first for better layer caching
COPY go.mod go.sum* ./
RUN go mod download

# Copy source code and build
COPY . .
RUN go build -o main

# Stage 2: Final image
FROM ubuntu:24.04
WORKDIR /app

# Combine apt-get commands to reduce layers and cleanup in same layer
RUN apt-get update && apt-get install -y \
    ffmpeg \
    wget \
    curl \
    unzip \
    npm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install yt-dlp
RUN wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -O /usr/local/bin/yt-dlp \
    && chmod +x /usr/local/bin/yt-dlp

# Install deno
RUN wget -qO- https://deno.land/install.sh | sh

# Set path for deno
ENV PATH="/root/.deno/bin:${PATH}"

# Copy binary and config from builder
COPY --from=builder /app/main .
COPY cookies.txt /app/cookies.txt

CMD ["./main"]