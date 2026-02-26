package main

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

type AudioPipeQueueMessage struct {
	Id      int64           `json:"msg_id"`
	Message json.RawMessage `json:"message"`
}

type AudioProcessingMessage struct {
	Url string `json:"url"`
}

type Audio struct {
	Id                uuid.UUID `db:"id"`
	SourceId          string    `db:"source_id"`
	SourceName        *string   `db:"source_name"` // nullable
	StorageLocation   string    `db:"storage_location"`
	ThumbnailLocation *string   `db:"thumbnail_location"` // nullable
	DownloadCount     int       `db:"download_count"`
	CreatedAtUtc      time.Time `db:"created_at_utc"`
}

type YtdlpOutputLog struct {
	Id                   uuid.UUID `db:"id"`
	AudioId              uuid.UUID `db:"audio_id"`
	ProgressState        int       `db:"progress_state"`
	Title                *string   `db:"title"`            // nullable
	OutputLogBase64      *string   `db:"output_log"`       // nullable
	ErrorOutputLogBase64 *string   `db:"error_output_log"` // nullable
	CreatedAtUtc         time.Time `db:"created_at_utc"`
}
