package main

import (
	"encoding/json"
	"errors"
	"testing"
)

func TestParseAudioPipeURL(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		message string
		want    string
		wantErr bool
	}{
		{
			name:    "valid url",
			message: `{"url":"https://www.youtube.com/watch?v=abc123"}`,
			want:    "https://www.youtube.com/watch?v=abc123",
		},
		{
			name:    "playlist url",
			message: `{"url":"https://www.youtube.com/playlist?list=PLtest"}`,
			want:    "https://www.youtube.com/playlist?list=PLtest",
		},
		{
			name:    "plain http url",
			message: `{"url":"http://example.com/watch?v=x"}`,
			want:    "http://example.com/watch?v=x",
		},
		{name: "invalid json", message: `{`, wantErr: true},
		{name: "missing url", message: `{"title":"x"}`, wantErr: true},
		{name: "empty url", message: `{"url":""}`, wantErr: true},
		{name: "non-string url", message: `{"url":123}`, wantErr: true},
		{name: "ftp url", message: `{"url":"ftp://evil/x"}`, wantErr: true},
		{name: "flag as url", message: `{"url":"--exec=id"}`, wantErr: true},
		{name: "file url", message: `{"url":"file:///etc/passwd"}`, wantErr: true},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			got, err := parseAudioPipeURL(json.RawMessage(tt.message))
			if tt.wantErr {
				if err == nil {
					t.Fatalf("parseAudioPipeURL(%s) expected error", tt.message)
				}
				if !errors.Is(err, ErrPermanentMessage) {
					t.Fatalf("expected ErrPermanentMessage, got %v", err)
				}
				return
			}
			if err != nil {
				t.Fatalf("parseAudioPipeURL: %v", err)
			}
			if got != tt.want {
				t.Fatalf("got %q, want %q", got, tt.want)
			}
		})
	}
}

func TestIsYouTubePlaylistURL(t *testing.T) {
	t.Parallel()

	tests := []struct {
		url  string
		want bool
	}{
		{url: "https://www.youtube.com/playlist?list=PLabc", want: true},
		{url: "https://www.youtube.com/watch?v=abc", want: false},
		{url: "https://youtu.be/abc", want: false},
	}

	for _, tt := range tests {
		if got := isYouTubePlaylistURL(tt.url); got != tt.want {
			t.Fatalf("isYouTubePlaylistURL(%q) = %v, want %v", tt.url, got, tt.want)
		}
	}
}
