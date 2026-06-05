package main

import (
	"context"
	"fmt"
	"os"
)

const (
	SleepTimeInSeconds = 5
	StorageLocation    = "/app/sessions"
	OutputType         = "opus"
	ArchiveLocation    = "/etc/librebeats/46asd46as1das"
)

var logger IAudioOutputLogger

func main() {
	ctx := context.Background()
	if err := InitDBPool(ctx); err != nil {
		panic(err)
	}
	defer CloseDBPool()

	l, err := NewYtdlpLogger()
	if err != nil {
		panic(err)
	}
	logger = &l

	if !fileExists(ArchiveLocation) {
		if err := os.WriteFile(ArchiveLocation, []byte(""), 0o666); err != nil {
			panic(err)
		}
	}

	db, err := NewLibreDb()
	if err != nil {
		panic(err)
	}

	queueListener := createQueueListener()
	storage := NewStorageService()
	storage.EnsureBucketsExists()

	for {
		msg, err := listenForMessage(queueListener)
		if err != nil {
			fmt.Printf("queue read error: %v\n", err)
			sleep()
			continue
		}
		if msg == nil {
			continue
		}

		fmt.Printf("Received message from queue\n Message id: %d (read_ct=%d)\n Message: %s\n", msg.Id, msg.ReadCT, msg.Message)

		outputLocation := fmt.Sprintf("%s/run_%d", StorageLocation, msg.Id)
		filesToDelete := []string{outputLocation}

		processErr := processQueueMessage(msg, db, storage)
		if processErr != nil {
			if handleErr := queueListener.HandleFailure(msg, processErr); handleErr != nil {
				fmt.Printf("queue failure handling error for msg %d: %v\n", msg.Id, handleErr)
			}
			cleanUopFiles(filesToDelete)
			continue
		}

		if err := queueListener.Ack(msg.Id); err != nil {
			fmt.Printf("failed to ack message %d: %v\n", msg.Id, err)
			cleanUopFiles(filesToDelete)
			continue
		}

		cleanUopFiles(filesToDelete)
	}
}
