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
	lastinsertedId, err := l.database.InsertWithReturningIdUUID("INSERT INTO YtdlpOutputLog (Title, ProgressState) VALUES ($1, $2) RETURNING id", title, Created)
	if err != nil {
		return nil, err
	}
	return &YtdlpOutputLog{
		Id:            lastinsertedId,
		ProgressState: int(Created),
		Title:         title,
	}, nil
}

func (l *YtdlpLogger) UpdateLog(log *YtdlpOutputLog) error {
	_, err := l.database.Pool.Exec(context.Background(), "UPDATE YtdlpOutputLog SET Title = $1, Output = $2, ErrorOutput = $3, ProgressState = $4, FinishedAtUtc = $5 WHERE id = $6", log.Title, log.OutputLog, log.ErrorOutputLog, log.ProgressState, log.FinishedAtUtc, log.Id)
	return err
}
