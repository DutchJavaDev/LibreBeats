FROM golang:1.26 AS builder
WORKDIR /app
COPY . .
RUN go build -o main

FROM ubuntu:24.04
WORKDIR /app

COPY --from=builder /app/main .

COPY cookies.txt /app/cookies.txt

# install ffmpeg
RUN apt-get update && apt-get install -y ffmpeg

# install wget
RUN apt-get install -y wget

# install curl
RUN apt-get install -y curl

# install unzip
RUN apt-get install -y unzip

# install deno  / need to set path ??
RUN wget -qO- https://deno.land/install.sh | sh

# install yt-dlp
RUN wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -O /usr/local/bin/yt-dlp && chmod +x /usr/local/bin/yt-dlp

# Install npm
RUN apt-get install -y npm

CMD ["./main"]