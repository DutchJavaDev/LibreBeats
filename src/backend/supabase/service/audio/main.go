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

	var logger = NewYtdlpLogger()

	for true {
		audioQueueMessage, _ := listenForMessage(&queueListener)

		if audioQueueMessage == nil {
			continue
		}

		fmt.Printf("Received message from queue\n Message id: %d\n Message: %s\n", audioQueueMessage.Id, audioQueueMessage.Message)

		messageBody := map[string]interface{}{}

		err := json.Unmarshal(audioQueueMessage.Message, &messageBody)

		if err != nil {
			log, _ := logger.CreateNewLog(fmt.Sprintf("Failed to unmarshal message body for message id: %d", audioQueueMessage.Id))
			log.OutputLogBase64 = string(audioQueueMessage.Message)
			log.ErrorOutputLogBase64 = fmt.Sprintf("Error: %s", err.Error())
			log.ProgressState = int(Failed)
			logger.UpdateLog(log)
			fmt.Printf("Failed to unmarshal message body for message id: %d\n Error: %s\n", audioQueueMessage.Id, err.Error())
			continue
		}

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

		if !pathExists(basePath) {
			err := os.Mkdir(basePath, fs.ModePerm|fs.ModeDir)
			if err != nil {
				log, _ := logger.CreateNewLog(fmt.Sprintf("Failed to create base directory for message id: %d", audioQueueMessage.Id))
				log.ErrorOutputLogBase64 = fmt.Sprintf("Error: %s", err.Error())
				log.ProgressState = int(Failed)
				log.FinishedAtUtc = time.Now()
				logger.UpdateLog(log)
				continue
			}
		}

		if !pathExists(outputLocation) {
			err := os.Mkdir(outputLocation, fs.ModePerm|fs.ModeDir)
			if err != nil {
				log, _ := logger.CreateNewLog(fmt.Sprintf("Failed to create output directory for message id: %d", audioQueueMessage.Id))
				log.ErrorOutputLogBase64 = fmt.Sprintf("Error: %s", err.Error())
				log.ProgressState = int(Failed)
				log.FinishedAtUtc = time.Now()
				logger.UpdateLog(log)
				continue
			}
		}

		// split off between playlist and single download
		if !isPlaylist {
			// Single
			_, err := FlatSingleDownload(outputLocation, idsFile, namesFile, durationFile, playlistTitleFile, playlistIdFile, sourceUrl, logOutput, logOutputError, "opus")

			if err != nil {
				log, _ := logger.CreateNewLog(fmt.Sprintf("Failed to download single video for message id: %d", audioQueueMessage.Id))
				log.OutputLogBase64 = string(audioQueueMessage.Message)
				log.ErrorOutputLogBase64 = fmt.Sprintf("Error: %s", err.Error())
				log.ProgressState = int(Failed)
				log.FinishedAtUtc = time.Now()
				logger.UpdateLog(log)
				fmt.Printf("Failed to download single video for message id: %d\n Error: %s\n", audioQueueMessage.Id, err.Error())
				cleanUopFiles(filesToDelete)
				continue
			}

			ids, err := readLines(idsFile)

			if err != nil {
				log, _ := logger.CreateNewLog(fmt.Sprintf("Failed to read IDs file for message id: %d", audioQueueMessage.Id))
				log.ErrorOutputLogBase64 = fmt.Sprintf("Error: %s", err.Error())
				log.ProgressState = int(Failed)
				log.FinishedAtUtc = time.Now()
				logger.UpdateLog(log)
				cleanUopFiles(filesToDelete)
				continue
			}

			audioFilePath := fmt.Sprintf("%s/%s.opus", outputLocation, ids[0])
			imageFilePath := fmt.Sprintf("%s/%s.jpg", outputLocation, ids[0])

			// Upload to storage
			audioUploadResponse, err := storage.UploadAudioFile(audioFilePath, fmt.Sprintf("%s.opus", ids[0]))

			if err != nil {
				log, _ := logger.CreateNewLog(fmt.Sprintf("Failed to upload audio file %s for message id: %d", audioFilePath, audioQueueMessage.Id))
				log.ErrorOutputLogBase64 = fmt.Sprintf("Error: %s", err.Error())
				log.ProgressState = int(Failed)
				log.FinishedAtUtc = time.Now()
				logger.UpdateLog(log)
			}

			imageUploadResponse, err := storage.UploadImageFile(imageFilePath, fmt.Sprintf("%s.jpg", ids[0]))

			if err != nil {
				log, _ := logger.CreateNewLog(fmt.Sprintf("Failed to upload image file %s file for message id: %d", imageFilePath, audioQueueMessage.Id))
				log.ErrorOutputLogBase64 = fmt.Sprintf("Error: %s", err.Error())
				log.ProgressState = int(Failed)
				log.FinishedAtUtc = time.Now()
				logger.UpdateLog(log)
			}

			fmt.Printf("Audio storage location: %s\n", audioUploadResponse.Key)
			fmt.Printf("Image storage location: %s\n", imageUploadResponse.Key)
		} else {
			// Playlist
			// Get playlist Id
		}

		// Clean up files
		cleanUopFiles(filesToDelete)
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

func cleanUopFiles(files []string) {
	for _, file := range files {
		err := os.RemoveAll(file)
		if err != nil {
			fmt.Printf("Failed to delete file: %s\n", file)
		} else {
			fmt.Printf("Deleted: %s\n", file)
		}
	}
}
