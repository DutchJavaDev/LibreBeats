package main

import "context"

type IYtdlpLogger interface {
	CreateNewLog(title string) (*YtdlpOutputLog, error)
	UpdateLog(log *YtdlpOutputLog) error
}

type YtdlpLogger struct {
	IYtdlpLogger
	database BaseTable
}

func NewYtdlpLogger() *YtdlpLogger {
	// Will throw an error if its missing a method implementation from interface
	// will throw a compile time error
	var _ IYtdlpLogger = (*YtdlpLogger)(nil)

	return &YtdlpLogger{}
}

func (l *YtdlpLogger) CreateNewLog(title string) (*YtdlpOutputLog, error) {
	lastinsertedId, err := l.database.InsertWithReturningIdUUID("INSERT INTO YtdlpOutputLog (title, progressState) VALUES ($1, $2) RETURNING id", title, 0)
	if err != nil {
		return nil, err
	}
	return &YtdlpOutputLog{
		Id:            lastinsertedId,
		ProgressState: 0,
		Title:         &title,
	}, nil
}

func (l *YtdlpLogger) UpdateLog(log *YtdlpOutputLog) error {
	_, err := l.database.Pool.Exec(context.Background(), "UPDATE YtdlpOutputLog SET title = $1, outputlog = $2, erroroutputlog = $3, progressstate = $4 WHERE id = $5", log.Title, log.OutputLogBase64, log.ErrorOutputLogBase64, log.ProgressState, log.Id)
	return err
}
