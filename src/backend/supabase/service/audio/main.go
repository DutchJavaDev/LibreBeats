package main

import (
	"fmt"
	"os"
	"time"
)

const (
	SleepTimeInSeconds = 5
)

func main() {
	// Setup database connection pool
	CreateConnectionPool()

	// Create queue listener
	var queueListener = *createQueueListener()

	for true {
		audioQueueMessage, _ := listenForMessage(&queueListener)

		if audioQueueMessage == nil {
			continue
		}

		fmt.Printf("Received message from queue\n Message id: %d\n Message: %s\n", audioQueueMessage.Id, audioQueueMessage.Message)

		// split off between playlist and single download

		// check if url is a playlist or single video

		// re-think way to handle playlist downloads,
		// use old method in mvp where it writes the information to a file and then reads it back to update the database

		// Works ish
		download := FlatSingleDownload("archive.txt", "ids.txt", "names.txt", "duration.txt", "playlist_title.txt", "playlist_id.txt", "https://www.youtube.com/watch?v=s-uEFHxZ_nE", "output.log", "error.log", "", "opus")

		// Handle download result
		if !download {
			fmt.Println("Failed to download playlist")
		} else {
			fmt.Println("Playlist downloaded successfully")
		}
	}
}

func listenForMessage(queue *QueueListener) (*AudioPipeQueueMessage, error) {
	audioQueueMessage, err := queue.Pop()

	if err != nil || audioQueueMessage == nil {
		HandleError(err)
		sleep()
		return nil, err
	}

	return audioQueueMessage, nil
}

func createQueueListener() *QueueListener {
	connectionString := os.Getenv("POSTGRES_BACKEND_URL")
	queueName := os.Getenv("QUEUE_NAME")

	if connectionString == "" {
		panic("POSTGRES_BACKEND_URL environment variable is not set")
	}

	if queueName == "" {
		panic("QUEUE_NAME environment variable is not set")
	}

	return &QueueListener{
		ConnectionString: connectionString,
		QueueName:        queueName,
	}
}

func sleep() {
	fmt.Printf("Sleeping for %d seconds...\n", SleepTimeInSeconds)
	time.Sleep(SleepTimeInSeconds * time.Second)
}

func HandleError(err error) {
	if err != nil {
		fmt.Println(err.Error())
	}
}
