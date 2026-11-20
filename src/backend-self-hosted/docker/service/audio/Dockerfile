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

# Download and install the OFFICIAL musl-compatible yt-dlp binary.
# Pinned on purpose: a "latest" download URL is cached by Docker, so a rebuild
# keeps the yt-dlp it first fetched. A YouTube 403 is often a stale yt-dlp.
# To update, set YTDLP_VERSION to a tag from github.com/yt-dlp/yt-dlp/releases
# (or pass --build-arg YTDLP_VERSION=<tag> to docker compose build).
ARG YTDLP_VERSION=2026.10.26
RUN wget https://github.com/yt-dlp/yt-dlp/releases/download/${YTDLP_VERSION}/yt-dlp_musllinux -O /usr/bin/yt-dlp \
    && chmod +x /usr/bin/yt-dlp
    
# Install deno (using Alpine's package or musl build)
RUN apk add --no-cache deno

# Copy the static binary and config
COPY --from=builder /app/main .
COPY cookies.txt /app/cookies.txt

CMD ["./main"]