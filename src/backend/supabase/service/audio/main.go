package main

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"strings"
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

	// Storage
	var storage = NewStorageService()

	//var logger = NewYtdlpLogger()

	for true {
		audioQueueMessage, _ := listenForMessage(&queueListener)

		if audioQueueMessage == nil {
			continue
		}

		fmt.Printf("Received message from queue\n Message id: %d\n Message: %s\n", audioQueueMessage.Id, audioQueueMessage.Message)

		messageBody := map[string]interface{}{}

		json.Unmarshal(audioQueueMessage.Message, &messageBody)

		// check if url is a playlist or single video
		sourceUrl := string(messageBody["url"].(string))
		isPlaylist := strings.Contains(sourceUrl, "playlist?")

		basePath := "/app/temp"
		outputLocation := fmt.Sprintf("%s/%d", basePath, audioQueueMessage.Id)
		idsFile := fmt.Sprintf("%s/ids.txt", outputLocation)
		namesFile := fmt.Sprintf("%s/names.txt", outputLocation)
		durationFile := fmt.Sprintf("%s/duration.txt", outputLocation)
		playlistTitleFile := fmt.Sprintf("%s/playlist_title.txt", outputLocation)
		playlistIdFile := fmt.Sprintf("%s/playlist_id.txt", outputLocation)
		logOutput := fmt.Sprintf("%s/output.log", outputLocation)
		logOutputError := fmt.Sprintf("%s/error.log", outputLocation)

		if !pathExists(basePath) {
			err := os.Mkdir(basePath, fs.ModePerm|fs.ModeDir)
			if err != nil {
				fmt.Println(err.Error())
				panic("Failed to create base directory")
			}
		}

		if !pathExists(outputLocation) {
			err := os.Mkdir(outputLocation, fs.ModePerm|fs.ModeDir)
			if err != nil {
				fmt.Println(err.Error())
				panic("Failed to create output directory")
			}
		}

		filesToDelete := []string{
			idsFile,
			namesFile,
			durationFile,
			playlistTitleFile,
			playlistIdFile,
			logOutput,
			logOutputError,
			outputLocation,
		}
		// split off between playlist and single download
		if !isPlaylist {
			// Single
			download := FlatSingleDownload(outputLocation, idsFile, namesFile, durationFile, playlistTitleFile, playlistIdFile, sourceUrl, logOutput, logOutputError, "opus")

			// Handle download result
			if !download {
				fmt.Println("Failed to download single video")
			} else {
				fmt.Println("Single video downloaded successfully")

				ids, err := readLines(idsFile)

				if err != nil {
					fmt.Println("Failed to read IDs file")
				}

				audioFilePath := fmt.Sprintf("%s/%s.opus", outputLocation, ids[0])
				imageFilePath := fmt.Sprintf("%s/%s.jpg", outputLocation, ids[0])

				// Upload to storage
				audioUploadResponse, err := storage.UploadAudioFile(audioFilePath, fmt.Sprintf("%s.opus", ids[0]))

				if err != nil {
					fmt.Println("Failed to upload audio file")
				}

				imageUploadResponse, err := storage.UploadImageFile(imageFilePath, fmt.Sprintf("%s.jpg", ids[0]))

				if err != nil {
					fmt.Println("Failed to upload image file")
				}

				fmt.Printf("Audio: %s\n", audioUploadResponse.Key)
				fmt.Printf("Image: %s\n", imageUploadResponse.Key)
			}

		} else {
			// Playlist
			// Get playlist Id
		}

		// re-think way to handle playlist downloads,
		// use old method in mvp where it writes the information to a file and then reads it back to update the database

		// Works ish
		// download := FlatSingleDownload("archive.txt", "ids.txt", "names.txt", "duration.txt", "playlist_title.txt", "playlist_id.txt", "https://www.youtube.com/watch?v=s-uEFHxZ_nE", "output.log", "error.log", "opus")

		// Handle download result
		// if !download {
		// 	fmt.Println("Failed to download playlist")
		// } else {
		// 	fmt.Println("Playlist downloaded successfully")
		// }

		// Clean up files
		for _, file := range filesToDelete {
			err := os.RemoveAll(file)
			if err != nil {
				fmt.Printf("Failed to delete file: %s\n", file)
			} else {
				fmt.Printf("Deleted: %s\n", file)
			}
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
