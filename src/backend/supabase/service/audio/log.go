package main

import (
	"context"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5"
)

type IAudioOutputLogger interface {
	CreateNewLog(title string) (AudioOutput, error)
	UpdateLog(log *AudioOutput) error
}

type AudioOutputLogger struct {
	IAudioOutputLogger
	ConnectionString string
}

func NewYtdlpLogger() AudioOutputLogger {
	// Will throw an error if its missing a method implementation from interface
	// will throw a compile time error
	var _ IAudioOutputLogger = (*AudioOutputLogger)(nil)

	connectionString := os.Getenv("POSTGRES_BACKEND_URL")

	if connectionString == "" {
		panic("POSTGRES_BACKEND_URL environment variable is not set")
	}

	return AudioOutputLogger{
		ConnectionString: connectionString,
	}
}

func (l *AudioOutputLogger) CreateNewLog(title string) (AudioOutput, error) {
	connection, err := pgx.Connect(context.Background(), l.ConnectionString)

	if err != nil {
		return AudioOutput{}, err
	}

	defer connection.Close(context.Background())

	var lastinsertedId = 1

	trans, err := connection.Begin(context.Background())

	scanError := trans.QueryRow(context.Background(), "INSERT INTO Librebeats.AudioOutputLog (Title, ProgressState) VALUES ($1, $2) RETURNING id", title, Created).Scan(&lastinsertedId)

	if scanError != nil {
		return AudioOutput{}, err
	}

	trans.Commit(context.Background())

	return AudioOutput{
		Id:            lastinsertedId,
		ProgressState: int(Created),
		Title:         &title,
	}, nil
}

func (l *AudioOutputLogger) UpdateLog(log *AudioOutput) error {
	connection, err := pgx.Connect(context.Background(), l.ConnectionString)

	if err != nil {
		return err
	}
	defer connection.Close(context.Background())

	trans, err := connection.Begin(context.Background())

	_, transError := trans.Exec(context.Background(), "UPDATE Librebeats.AudioOutputLog SET Title = $1, Output = $2, ErrorOutput = $3, ProgressState = $4, FinishedAtUtc = $5 WHERE id = $6", log.Title, log.Output, log.ErrorOutput, log.ProgressState, log.FinishedAtUtc, log.Id)

	if transError != nil {
		fmt.Println(transError.Error())
	}

	trans.Commit(context.Background())

	return transError
}
