package main

import (
	"context"
	"os"
	"time"

	"github.com/jackc/pgx/v5"
)

type ILibreDb interface {
	NewRawAudioEntry(source string, audioLocation string, thumbnailLocation string, durration int) (RawBeat, error)
	NewBeatEntry(rawBeat *RawBeat, title string, arties string, tags string, streamingUrl string, thumbnailUrl string) (err error, insertedId int)
	NewBeatMixEntry(beatMix *BeatMix) error
	NewBeatMixBeatEntry(beatId int, beatMixId int) error
	GetBeatMixByName(name string) (error, BeatMix)
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

func (db *LibreDb) NewRawAudioEntry(source string, audioLocation string, thumbnailLocation string, duration int) (RawBeat, error) {
	connection, err := pgx.Connect(context.Background(), db.ConnectionString)
	defer connection.Close(context.Background())

	if err != nil {
		return RawBeat{}, err
	}

	statement, err := connection.Begin(context.Background())

	if err != nil {
		return RawBeat{}, err
	}

	lastinsertedId := -1

	err = statement.QueryRow(context.Background(), "INSERT INTO Librebeats.RawBeat (Source, AudioLocation, ThumbnailLocation, Duration) VALUES($1, $2, $3, $4) RETURNING Id",
		source, audioLocation, thumbnailLocation, duration).
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

func (db *LibreDb) NewBeatEntry(rawBeat *RawBeat, title string, arties string, tags string, streamingUrl string, thumbnailUrl string) (err error, insertedId int) {
	connection, err := pgx.Connect(context.Background(), db.ConnectionString)
	defer connection.Close(context.Background())

	if err != nil {
		return err, -1
	}

	statement, err := connection.Begin(context.Background())

	if err != nil {
		return err, -1
	}

	err = statement.QueryRow(context.Background(), "INSERT INTO Librebeats.Beat (RawBeatId, Title, Artist, Tags, StreamingUrl, ThumbnailUrl) VALUES($1, $2, $3, $4, $5, $6) RETURNING Id",
		rawBeat.Id, title, arties, tags, streamingUrl, thumbnailUrl).Scan(&insertedId)

	if err != nil {
		return err, -1
	}

	err = statement.Commit(context.Background())

	if err != nil {
		return err, -1
	}

	return nil, insertedId
}

func (db *LibreDb) NewBeatMixEntry(beatMix *BeatMix) error {
	connection, err := pgx.Connect(context.Background(), db.ConnectionString)
	defer connection.Close(context.Background())

	if err != nil {
		return err
	}

	statement, err := connection.Begin(context.Background())

	if err != nil {
		return err
	}

	err = statement.QueryRow(context.Background(), "INSERT INTO Librebeats.BeatMix (Title, ThumbnailUrl) VALUES($1, $2) RETURNING Id",
		beatMix.Title, beatMix.ThumbnailURL).Scan(&beatMix.Id)

	if err != nil {
		return err
	}

	err = statement.Commit(context.Background())

	if err != nil {
		return err
	}

	return nil
}

func (db *LibreDb) NewBeatMixBeatEntry(beatId int, beatMixId int) error {

	connection, err := pgx.Connect(context.Background(), db.ConnectionString)
	defer connection.Close(context.Background())

	if err != nil {
		return err
	}

	statement, err := connection.Begin(context.Background())

	if err != nil {
		return err
	}

	_, err = statement.Exec(context.Background(), "INSERT INTO Librebeats.BeatMixBeat (BeatId, BeatMixId) VALUES($1, $2)", beatMixId, beatId)

	if err != nil {
		return err
	}

	err = statement.Commit(context.Background())

	if err != nil {
		return err
	}

	return nil
}

func (db *LibreDb) GetBeatMixByName(name string) (error, BeatMix) {
	connection, err := pgx.Connect(context.Background(), db.ConnectionString)
	defer connection.Close(context.Background())
	var beatMix BeatMix
	beatMix.Id = -1

	if err != nil {
		return err, beatMix
	}

	query := "SELECT Id, Title, ThumbnailUrl FROM Librebeats.BeatMix WHERE Title = $1"

	err = connection.QueryRow(context.Background(), query, name).Scan(&beatMix.Id, &beatMix.Title, &beatMix.ThumbnailURL)

	if err != nil || beatMix.Id == -1 {
		return err, beatMix
	}

	return nil, beatMix
}
