package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"
)

// parseAudioPipeURL extracts the YouTube URL from a queue message body.
func parseAudioPipeURL(message json.RawMessage) (string, error) {
	var body map[string]interface{}
	if err := json.Unmarshal(message, &body); err != nil {
		return "", fmt.Errorf("unmarshal queue message: %w", err)
	}
	rawURL, ok := body["url"]
	if !ok {
		return "", errors.New("queue message missing url field")
	}
	url, ok := rawURL.(string)
	if !ok || url == "" {
		return "", errors.New("queue message url must be a non-empty string")
	}
	return url, nil
}

// isYouTubePlaylistURL returns true when the URL targets a YouTube playlist.
func isYouTubePlaylistURL(sourceURL string) bool {
	return strings.Contains(sourceURL, "playlist?")
}
