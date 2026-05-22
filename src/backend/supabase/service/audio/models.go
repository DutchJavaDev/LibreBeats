package main

import (
	"encoding/json"
	"time"
)

type ProgressState int

const (
	Failed      ProgressState = iota
	Created     ProgressState = iota
	Downloading ProgressState = iota
	Completed   ProgressState = iota
)

type AudioPipeQueueMessage struct {
	Id      int64           `json:"msg_id"`
	Message json.RawMessage `json:"message"`
}

type AudioProcessingMessage struct {
	Url string `json:"url"`
}

type Beat struct {
	Id           int       `json:"id" db:"id" gorm:"primaryKey;autoIncrement"`
	RawBeatId    int       `json:"raw_beat_id" db:"raw_beat_id" gorm:"not null;index"` // foreign key to Audio/RawBeat
	Title        *string   `json:"title" db:"title" gorm:"not null"`
	Artist       *string   `json:"artist" db:"artist" gorm:"not null"`
	Tags         *[]string `json:"tags" db:"tags" gorm:"not null"`
	StreamingURL *string   `json:"streaming_url" db:"streaming_url" gorm:"not null"`
	ThumbnailURL *string   `json:"thumbnail_url" db:"thumbnail_url" gorm:"not null"`
}

type RawBeat struct {
	Id                int       `json:"id" db:"id" gorm:"primaryKey;autoIncrement"`
	Source            *string   `json:"source" db:"source" gorm:"not null"`
	AudioLocation     *string   `json:"audio_location" db:"audio_location" gorm:"not null"`
	ThumbnailLocation *string   `json:"thumbnail_location" db:"thumbnail_location" gorm:"not null"`
	DownloadCount     int       `json:"download_count" db:"download_count" gorm:"not null;default:0"`
	CreatedAtUtc      time.Time `json:"created_at_utc" db:"created_at_utc" gorm:"not null;default:now()"`
	Duration          int       `json:"duration" db:"duration" gorm:"not null;default 0"`
}

type BeatMix struct {
	Id           int       `json:"id" db:"id" gorm:"column:id;primaryKey;autoIncrement"`
	Title        string    `json:"title" db:"title" gorm:"column:title;type:text;not null;unique"`
	ThumbnailURL string    `json:"thumbnailUrl" db:"thumbnailurl" gorm:"column:thumbnailurl;type:text;not null"`
	Beatable     bool      `json:"beatable" db:"beatable" gorm:"column:beatable;not null;default:true"`
	CreatedOn    time.Time `json:"createdOn" db:"createdon" gorm:"column:createdon;type:timestamptz;not null;default:now()"`
}

type AudioOutput struct {
	Id            int        `json:"id" db:"id" gorm:"primaryKey;autoIncrement"`
	Title         *string    `json:"title" db:"title" gorm:"not null"`
	ProgressState int        `json:"progress_state" db:"progress_state" gorm:"not null"`
	Output        *string    `json:"output,omitempty" db:"output" gorm:"default:null"`             // nullable
	ErrorOutput   *string    `json:"error_output,omitempty" db:"error_output" gorm:"default:null"` // nullable
	StartedAtUtc  *time.Time `json:"started_at_utc" db:"started_at_utc" gorm:"not null;default:now()"`
	FinishedAtUtc time.Time  `json:"finished_at_utc,omitempty" db:"finished_at_utc" gorm:"default:null"` // nullable
}
