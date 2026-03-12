package main

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

type ProgressState int

const (
	Created     ProgressState = iota
	InProgress  ProgressState = iota
	Completed   ProgressState = iota
	Downloading ProgressState = iota
	Failed      ProgressState = iota
)

type AudioPipeQueueMessage struct {
	Id      int64           `json:"msg_id"`
	Message json.RawMessage `json:"message"`
}

type AudioProcessingMessage struct {
	Url string `json:"url"`
}

type Audio struct {
	Id                int       `json:"id" db:"id"`
	Title             string    `json:"title" db:"title"`
	Artist            string    `json:"artist" db:"artist"`
	Album             string    `json:"album" db:"album"`
	AudioLocation     string    `json:"audioLocation" db:"audio_location"`
	ThumbnailLocation string    `json:"thumbnailLocation" db:"thumbnail_location"`
	StreamingURL      string    `json:"streamingUrl" db:"streaming_url"`
	ThumbnailURL      string    `json:"thumbnailUrl" db:"thumbnail_url"`
	DownloadCount     int       `json:"downloadCount" db:"download_count"`
	CreatedAtUTC      time.Time `json:"createdAtUtc" db:"created_at_utc"`
}

type YtdlpOutputLog struct {
	Id             uuid.UUID `db:"id"`
	AudioId        uuid.UUID `db:"audio_id"`
	ProgressState  int       `db:"progress_state"`
	Title          string    `db:"title"`            // nullable
	OutputLog      string    `db:"output_log"`       // nullable
	ErrorOutputLog string    `db:"error_output_log"` // nullable
	CreatedAtUtc   time.Time `db:"created_at_utc"`
	FinishedAtUtc  time.Time `db:"finished_at_utc"` // nullable
}
