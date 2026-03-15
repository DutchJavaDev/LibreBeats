package main

import (
	"context"
	"os"
	"time"

	"github.com/jackc/pgx/v5"
)

type ILibreDb interface {
	NewRawAudioEntry(source string, audioLocation string, thumbnailLocation string, durration int) (RawBeat, error)
	NewBeatEntry(rawBeat *RawBeat, title string, arties string, tags string, streamingUrl string, thumbnailUrl string) error
}

type LibreDb struct {
	ILibreDb
	ConnectionString string
}

func NewLibreDb() LibreDb {

	var _ ILibreDb = (*LibreDb)(nil)

	connectionString := os.Getenv("POSTGRES_BACKEND_URL")

	if connectionString == "" {
		panic("POSTGRES_BACKEND_URL environment variable is not set")
	}
	return LibreDb{
		ConnectionString: connectionString,
	}
}

func (db *LibreDb) NewRawAudioEntry(source string, audioLocation string, thumbnailLocation string, durration int) (RawBeat, error) {
	connection, err := pgx.Connect(context.Background(), db.ConnectionString)

	if err != nil {
		return RawBeat{}, err
	}

	statement, err := connection.Begin(context.Background())

	if err != nil {
		return RawBeat{}, err
	}

	lastinsertedId := -1

	err = statement.QueryRow(context.Background(), "INSERT INTO Librebeats.RawBeat (Source, AudioLocation, ThumbnailLocation, Durration) VALUES($1, $2, $3, $4) RETURNING Id", source, audioLocation, thumbnailLocation, durration).
		Scan(&lastinsertedId)

	if err != nil {
		return RawBeat{}, err
	}

	err = statement.Commit(context.Background())

	if err != nil {
		return RawBeat{}, err
	}

	return RawBeat{
		Id:                lastinsertedId,
		Source:            &source,
		AudioLocation:     &audioLocation,
		ThumbnailLocation: &thumbnailLocation,
		DownloadCount:     0,
		CreatedAtUtc:      time.Now(),
	}, nil
}

func (db *LibreDb) NewBeatEntry(rawBeat *RawBeat, title string, arties string, tags string, streamingUrl string, thumbnailUrl string) error {
	connection, err := pgx.Connect(context.Background(), db.ConnectionString)

	if err != nil {
		return err
	}

	statement, err := connection.Begin(context.Background())

	if err != nil {
		return err
	}

	_, err = statement.Exec(context.Background(), "INSERT INTO Librebeats.Beat (RawBeatId, Title, Artist, Tags, StreamingUrl, ThumbnailUrl) VALUES($1, $2, $3, $4, $5, $6) RETURNING Id", rawBeat.Id, title, arties, tags, streamingUrl, thumbnailUrl)

	if err != nil {
		return err
	}

	err = statement.Commit(context.Background())

	if err != nil {
		return err
	}

	return nil
}
