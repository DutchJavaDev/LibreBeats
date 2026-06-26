package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type IQueueListener interface {
	Read() (*AudioPipeQueueMessage, error)
	Ack(msgID int64) error
	HandleFailure(msg *AudioPipeQueueMessage, processErr error) error
}

type QueueListener struct {
	IQueueListener
	pool                 *pgxpool.Pool
	QueueName            string
	dlqName              string
	visibilityTimeoutSec int
	maxReadCount         int64
}

// Read claims a message with a visibility timeout; the message is not removed until Ack.
func (ql *QueueListener) Read() (*AudioPipeQueueMessage, error) {
	ctx := context.Background()

	var msg AudioPipeQueueMessage
	err := ql.pool.QueryRow(ctx,
		"SELECT msg_id, read_ct, message FROM pgmq.read($1, $2, 1)",
		ql.QueueName, ql.visibilityTimeoutSec).
		Scan(&msg.Id, &msg.ReadCT, &msg.Message)

	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	return &msg, nil
}

// Ack permanently removes a successfully processed message.
func (ql *QueueListener) Ack(msgID int64) error {
	ctx := context.Background()
	var deleted bool
	err := ql.pool.QueryRow(ctx,
		"SELECT pgmq.delete($1, $2)",
		ql.QueueName, msgID).
		Scan(&deleted)
	if err != nil {
		return fmt.Errorf("ack message %d: %w", msgID, err)
	}
	if !deleted {
		return fmt.Errorf("ack message %d: not found", msgID)
	}
	return nil
}

// HandleFailure sends poison or exhausted messages to the DLQ; transient failures rely on VT retry.
func (ql *QueueListener) HandleFailure(msg *AudioPipeQueueMessage, processErr error) error {
	if msg == nil {
		return nil
	}

	if isPermanentQueueError(processErr) || msg.ReadCT >= ql.maxReadCount {
		fmt.Printf("moving message %d to DLQ (read_ct=%d): %v\n", msg.Id, msg.ReadCT, processErr)
		return ql.moveToDLQ(msg, processErr)
	}

	fmt.Printf("message %d will retry after visibility timeout (read_ct=%d): %v\n", msg.Id, msg.ReadCT, processErr)
	return nil
}

func (ql *QueueListener) moveToDLQ(msg *AudioPipeQueueMessage, cause error) error {
	ctx := context.Background()

	dlqPayload, err := wrapDLQPayload(msg, cause)
	if err != nil {
		return err
	}

	var dlqMsgID int64
	err = ql.pool.QueryRow(ctx,
		"SELECT pgmq.send($1, $2::jsonb)",
		ql.dlqName, dlqPayload).
		Scan(&dlqMsgID)
	if err != nil {
		return fmt.Errorf("send to dlq: %w", err)
	}

	fmt.Printf("enqueued DLQ message %d for source msg %d\n", dlqMsgID, msg.Id)
	return ql.Ack(msg.Id)
}

func wrapDLQPayload(msg *AudioPipeQueueMessage, cause error) ([]byte, error) {
	body := map[string]any{
		"original_msg_id": msg.Id,
		"read_ct":         msg.ReadCT,
		"message":         json.RawMessage(msg.Message),
	}
	if cause != nil {
		body["error"] = cause.Error()
	}
	return json.Marshal(body)
}
