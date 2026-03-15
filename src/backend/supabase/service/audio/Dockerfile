# Stage 1: Builder (stays the same)
FROM golang:1.26-alpine AS builder
WORKDIR /app
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o main

# Stage 2: Final image with Alpine
FROM alpine:latest
WORKDIR /app

# Install required system packages
RUN apk add --no-cache ffmpeg

# Download and install the OFFICIAL musl-compatible yt-dlp binary
RUN wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_musllinux -O /usr/bin/yt-dlp \
    && chmod +x /usr/bin/yt-dlp
    
# Install deno (using Alpine's package or musl build)
RUN apk add --no-cache deno

# Copy the static binary and config
COPY --from=builder /app/main .
COPY cookies.txt /app/cookies.txt

CMD ["./main"]