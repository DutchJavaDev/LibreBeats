package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"
)

// ErrPermanentMessage marks queue payloads that should not be retried (sent to DLQ).
var ErrPermanentMessage = errors.New("permanent queue message error")

func isPermanentQueueError(err error) bool {
	return errors.Is(err, ErrPermanentMessage)
}

// ErrUnavailableTrack marks one playlist track that will never download
// (private, removed, terminated). The playlist skips it instead of failing.
var ErrUnavailableTrack = errors.New("track unavailable")

// yt-dlp messages for videos that will never download. Lowercase, matched
// case-insensitively against the error log.
var unavailableTrackMarkers = []string{
	"video unavailable",
	"this video is private",
	"private video",
	"has been removed",
	"no longer available",
	"account associated with this video has been terminated",
}

func isUnavailableTrackLog(log string) bool {
	lower := strings.ToLower(log)
	for _, marker := range unavailableTrackMarkers {
		if strings.Contains(lower, marker) {
			return true
		}
	}
	return false
}

// parseAudioPipeURL extracts the YouTube URL from a queue message body.
func parseAudioPipeURL(message json.RawMessage) (string, error) {
	var body map[string]interface{}
	if err := json.Unmarshal(message, &body); err != nil {
		return "", fmt.Errorf("%w: unmarshal queue message: %v", ErrPermanentMessage, err)
	}
	rawURL, ok := body["url"]
	if !ok {
		return "", fmt.Errorf("%w: queue message missing url field", ErrPermanentMessage)
	}
	url, ok := rawURL.(string)
	if !ok || url == "" {
		return "", fmt.Errorf("%w: queue message url must be a non-empty string", ErrPermanentMessage)
	}
	if !strings.HasPrefix(url, "http://") && !strings.HasPrefix(url, "https://") {
		return "", fmt.Errorf("%w: queue message url must be an http(s) url", ErrPermanentMessage)
	}
	return url, nil
}

// isYouTubePlaylistURL returns true when the URL targets a YouTube playlist.
func isYouTubePlaylistURL(sourceURL string) bool {
	return strings.Contains(sourceURL, "playlist?")
}
