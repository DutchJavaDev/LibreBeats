# Stage 1: Builder
FROM golang:1.26-alpine AS builder
WORKDIR /app

COPY go.mod go.sum* ./
RUN go mod download

COPY . .
# Build a static binary (no libc dependencies)
RUN CGO_ENABLED=0 go build -o main

# Stage 2: Final image (Alpine for minimal size)
FROM alpine:latest
WORKDIR /app

# Install required system packages (without npm)
# --no-install-recommends avoids pulling extra packages
RUN apk add --no-cache ffmpeg wget curl unzip

# Install yt-dlp and deno in one layer, cleaning up as we go
RUN wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -O /usr/local/bin/yt-dlp \
    && chmod +x /usr/local/bin/yt-dlp \
    && wget https://github.com/denoland/deno/releases/latest/download/deno-x86_64-unknown-linux-gnu.zip \
    && unzip deno-x86_64-unknown-linux-gnu.zip \
    && chmod +x deno \
    && mv deno /usr/local/bin/deno \
    && rm deno-x86_64-unknown-linux-gnu.zip

# Copy the static binary and config
COPY --from=builder /app/main .
COPY cookies.txt /app/cookies.txt

CMD ["./main"]