package main

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
)

type IQueueListener interface {
	Pop() (map[string]interface{}, error)
}

type QueueListener struct {
	IQueueListener
	ConnectionString string
	QueueName        string
}

func (ql *QueueListener) Pop() (*AudioPipeQueueMessage, error) {

	conn, err := pgx.Connect(context.Background(), ql.ConnectionString)

	if err != nil {
		return nil, err
	}

	defer conn.Close(context.Background())

	var audioQueueMessage AudioPipeQueueMessage

	transaction, err := conn.Begin(context.Background())

	if err != nil {
		return nil, err
	}

	err = transaction.QueryRow(context.Background(), fmt.Sprintf("SELECT msg_id, message FROM pgmq.pop('%s')", ql.QueueName)).Scan(&audioQueueMessage.Id, &audioQueueMessage.Message)

	if err != nil {
		return nil, err
	}

	if err := transaction.Commit(context.Background()); err != nil {
		return nil, err
	}

	// var keyValues map[string]interface{}

	// if err := json.Unmarshal([]byte(result.Message), &keyValues); err != nil {
	// 	return AudioPipeQueueMessage{}, err
	// }

	return &audioQueueMessage, nil
}
