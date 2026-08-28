package main

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
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
	pool *pgxpool.Pool
}

func NewLibreDb() (LibreDb, error) {
	var _ ILibreDb = (*LibreDb)(nil)

	pool, err := requireDBPool()
	if err != nil {
		return LibreDb{}, err
	}
	return LibreDb{pool: pool}, nil
}

func (db *LibreDb) NewRawAudioEntry(source string, audioLocation string, thumbnailLocation string, duration int) (RawBeat, error) {
	ctx := context.Background()
	tx, err := db.pool.Begin(ctx)
	if err != nil {
		return RawBeat{}, err
	}
	defer tx.Rollback(ctx)

	var lastinsertedId int
	err = tx.QueryRow(ctx,
		"INSERT INTO Librebeats.RawBeat (Source, AudioLocation, ThumbnailLocation, Duration) VALUES($1, $2, $3, $4) ON CONFLICT (Source) DO UPDATE SET AudioLocation = EXCLUDED.AudioLocation, ThumbnailLocation = EXCLUDED.ThumbnailLocation, Duration = EXCLUDED.Duration RETURNING Id",
		source, audioLocation, thumbnailLocation, duration).
		Scan(&lastinsertedId)
	if err != nil {
		return RawBeat{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return RawBeat{}, err
	}

	return RawBeat{
		Id:                lastinsertedId,
		Source:            &source,
		AudioLocation:     &audioLocation,
		ThumbnailLocation: &thumbnailLocation,
		DownloadCount:     0,
		CreatedAtUtc:      time.Now(),
		Duration:          duration,
	}, nil
}

func (db *LibreDb) NewBeatEntry(rawBeat *RawBeat, title string, arties string, tags string, streamingUrl string, thumbnailUrl string) (error, int) {
	ctx := context.Background()
	tx, err := db.pool.Begin(ctx)
	if err != nil {
		return err, -1
	}
	defer tx.Rollback(ctx)

	var insertedId int
	err = tx.QueryRow(ctx,
		"INSERT INTO Librebeats.Beat (RawBeatId, Title, Artist, Tags, StreamingUrl, ThumbnailUrl) VALUES($1, $2, $3, $4, $5, $6) ON CONFLICT (StreamingUrl) DO UPDATE SET RawBeatId = EXCLUDED.RawBeatId, Title = EXCLUDED.Title, Artist = EXCLUDED.Artist, Tags = EXCLUDED.Tags, ThumbnailUrl = EXCLUDED.ThumbnailUrl RETURNING Id",
		rawBeat.Id, title, arties, tags, streamingUrl, thumbnailUrl).
		Scan(&insertedId)
	if err != nil {
		return err, -1
	}

	if err := tx.Commit(ctx); err != nil {
		return err, -1
	}

	return nil, insertedId
}

func (db *LibreDb) NewBeatMixEntry(beatMix *BeatMix) error {
	ctx := context.Background()
	tx, err := db.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	err = tx.QueryRow(ctx,
		"INSERT INTO Librebeats.BeatMix (Title, ThumbnailUrl) VALUES($1, $2) ON CONFLICT (Title) DO UPDATE SET ThumbnailUrl = EXCLUDED.ThumbnailUrl RETURNING Id",
		beatMix.Title, beatMix.ThumbnailURL).
		Scan(&beatMix.Id)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}

func (db *LibreDb) NewBeatMixBeatEntry(beatId int, beatMixId int) error {
	ctx := context.Background()
	tx, err := db.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx,
		"INSERT INTO Librebeats.BeatMixBeat (BeatId, BeatMixId) VALUES($1, $2) ON CONFLICT DO NOTHING",
		beatId, beatMixId)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}

func (db *LibreDb) GetBeatMixByName(name string) (error, BeatMix) {
	ctx := context.Background()
	var beatMix BeatMix
	beatMix.Id = -1

	err := db.pool.QueryRow(ctx,
		"SELECT Id, Title, ThumbnailUrl FROM Librebeats.BeatMix WHERE Title = $1",
		name).
		Scan(&beatMix.Id, &beatMix.Title, &beatMix.ThumbnailURL)

	if errors.Is(err, pgx.ErrNoRows) {
		return err, beatMix
	}
	if err != nil {
		return err, beatMix
	}

	return nil, beatMix
}
