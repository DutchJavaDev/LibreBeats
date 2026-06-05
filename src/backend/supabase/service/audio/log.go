package main

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

type IAudioOutputLogger interface {
	CreateNewLog(title string) (AudioOutput, error)
	UpdateLog(log *AudioOutput) error
}

type AudioOutputLogger struct {
	IAudioOutputLogger
	pool *pgxpool.Pool
}

func getLogger() IAudioOutputLogger {
	if logger == nil {
		l, err := NewYtdlpLogger()
		if err != nil {
			fmt.Printf("logger unavailable: %v\n", err)
			return noopLogger{}
		}
		logger = &l
	}
	return logger
}

type noopLogger struct{}

func (noopLogger) CreateNewLog(title string) (AudioOutput, error) {
	return AudioOutput{Title: &title, ProgressState: Failed}, nil
}

func (noopLogger) UpdateLog(*AudioOutput) error { return nil }

func NewYtdlpLogger() (AudioOutputLogger, error) {
	var _ IAudioOutputLogger = (*AudioOutputLogger)(nil)

	pool, err := requireDBPool()
	if err != nil {
		return AudioOutputLogger{}, err
	}

	return AudioOutputLogger{pool: pool}, nil
}

func (l *AudioOutputLogger) CreateNewLog(title string) (AudioOutput, error) {
	ctx := context.Background()
	tx, err := l.pool.Begin(ctx)
	if err != nil {
		return AudioOutput{}, err
	}
	defer tx.Rollback(ctx)

	var lastinsertedId int
	err = tx.QueryRow(ctx,
		"INSERT INTO Librebeats.AudioOutputLog (Title, ProgressState) VALUES ($1, $2) RETURNING id",
		title, Created.String()).
		Scan(&lastinsertedId)
	if err != nil {
		return AudioOutput{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return AudioOutput{}, err
	}

	return AudioOutput{
		Id:            lastinsertedId,
		ProgressState: Created,
		Title:         &title,
	}, nil
}

func (l *AudioOutputLogger) UpdateLog(log *AudioOutput) error {
	ctx := context.Background()
	tx, err := l.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx,
		`UPDATE Librebeats.AudioOutputLog
		 SET Title = $1, Output = $2, ErrorOutput = $3, ProgressState = $4, FinishedAtUtc = $5
		 WHERE id = $6`,
		log.Title, log.Output, log.ErrorOutput, log.ProgressState.String(), log.FinishedAtUtc, log.Id)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}
