package main

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
)

const (
	SleepTimeInSeconds = 5
	StorageLocation    = "/app/sessions"
)

var logger AudioOutputLogger = NewYtdlpLogger()

func main() {
	// db
	var db = NewLibreDb()

	// Create queue listener
	var queueListener = *createQueueListener()

	// Storage
	var storage = NewStorageService()

	storage.EnsureBucketsExists()

	for true {
		audioQueueMessage, _ := listenForMessage(&queueListener)

		if audioQueueMessage == nil {
			continue
		}

		fmt.Printf("Received message from queue\n Message id: %d\n Message: %s\n", audioQueueMessage.Id, audioQueueMessage.Message)

		messageBody := map[string]interface{}{}

		err := json.Unmarshal(audioQueueMessage.Message, &messageBody)

		if err != nil {
			ErrorLog(fmt.Sprintf("Failed to unmarshal message body for message id: %d", audioQueueMessage.Id), string(audioQueueMessage.Message), fmt.Sprintf("Error: %s", err.Error()))
			continue
		}

		// check if url is a playlist or single video
		sourceUrl := string(messageBody["url"].(string))
		isPlaylist := strings.Contains(sourceUrl, "playlist?")

		outputLocation := fmt.Sprintf("%s/run_%d", StorageLocation, audioQueueMessage.Id)
		idsFile := fmt.Sprintf("%s/ids.txt", outputLocation)
		namesFile := fmt.Sprintf("%s/names.txt", outputLocation)
		durationFile := fmt.Sprintf("%s/duration.txt", outputLocation)
		playlistTitleFile := fmt.Sprintf("%s/playlist_title.txt", outputLocation)
		playlistIdFile := fmt.Sprintf("%s/playlist_id.txt", outputLocation)
		tags := fmt.Sprintf("%s/tags.txt", outputLocation)
		logOutput := fmt.Sprintf("%s/output.log", outputLocation)
		logOutputError := fmt.Sprintf("%s/error.log", outputLocation)

		filesToDelete := []string{
			idsFile,
			namesFile,
			durationFile,
			playlistTitleFile,
			playlistIdFile,
			logOutput,
			tags,
			logOutputError,
			outputLocation,
		}

		if !tryCreateDirectory(StorageLocation) ||
			!tryCreateDirectory(outputLocation) {
			continue
		}

		// split off between playlist and single download
		if !isPlaylist {
			// Single
			_, err := FlatSingleDownload(outputLocation, idsFile, namesFile, durationFile, sourceUrl, tags, logOutput, logOutputError, "opus")

			if err != nil {
				errorLog, _ := readFile(logOutputError)
				ErrorLog("FlatSingleDownload had an error", fmt.Sprintf("Failed to download url: %s", string(messageBody["url"].(string))), errorLog)
				cleanUopFiles(filesToDelete)
				continue
			}

			if !fileExists(idsFile) ||
				!fileExists(namesFile) ||
				!fileExists(durationFile) {
				// Failed to creat needed files, check errors
				errorLog, _ := readFile(logOutputError)
				ErrorLog("Error Ytdlp did not create needed files", fmt.Sprintf("Failed to download url: %s", string(messageBody["url"].(string))), errorLog)
				cleanUopFiles(filesToDelete)
				continue
			}

			id, err := readFile(idsFile)
			name, err := readFile(namesFile)
			duration, err := readFile(durationFile)
			audioFilePath := fmt.Sprintf("%s/%s.opus", outputLocation, id)
			imageFilePath := fmt.Sprintf("%s/%s.jpg", outputLocation, id)

			// Upload to storage
			audioUploadResponse, err := storage.UploadAudioFile(audioFilePath, fmt.Sprintf("%s.opus", id))

			if err != nil {
				ErrorLog(fmt.Sprintf("Failed to upload audio file %s for message id: %d", audioFilePath, audioQueueMessage.Id),
					string(audioQueueMessage.Message),
					fmt.Sprintf("Error: %s", err.Error()))
				cleanUopFiles(filesToDelete)
				continue
			}

			imageUploadResponse, err := storage.UploadImageFile(imageFilePath, fmt.Sprintf("%s.jpeg", id))

			if err != nil {
				ErrorLog(fmt.Sprintf("Failed to upload image file %s file for message id: %d", imageFilePath,
					audioQueueMessage.Id),
					imageUploadResponse.Error,
					fmt.Sprintf("Error: %s", err.Error()))
				cleanUopFiles(filesToDelete)
				continue
			}

			audioStorageLocation := audioUploadResponse.Key
			imageStorageLocation := imageUploadResponse.Key

			// update database with entry....
			_dur, err := strconv.Atoi(duration)
			rawAudio, err := db.NewRawAudioEntry(sourceUrl, audioStorageLocation, imageStorageLocation, _dur)

			if err != nil {
				ErrorLog("Failed to create new RawAudio entry", sourceUrl, err.Error())
				cleanUopFiles(filesToDelete)
				continue
			}

			audioPublicUrl := storage.GetAudioPublicUrl(audioStorageLocation)
			thumbnailPublicUrl := storage.GetImagePublicUrl(imageStorageLocation)

			err = db.NewBeatEntry(&rawAudio, name, name, "", audioPublicUrl.SignedURL, thumbnailPublicUrl.SignedURL)

			if err != nil {
				ErrorLog("Failed to create a new Beat entry", sourceUrl, err.Error())
				cleanUopFiles(filesToDelete)
				continue
			}

		} else {
			// Playlist

			// Get playlist Id
		}

		// Clean up files
		cleanUopFiles(filesToDelete)
	}
}
