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
	OutputType         = "opus"
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
		tagsFile := fmt.Sprintf("%s/tags.txt", outputLocation)
		logOutput := fmt.Sprintf("%s/output.log", outputLocation)
		logOutputError := fmt.Sprintf("%s/error.log", outputLocation)

		filesToDelete := []string{
			idsFile,
			namesFile,
			durationFile,
			playlistTitleFile,
			playlistIdFile,
			logOutput,
			tagsFile,
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
			_, err := FlatSingleDownload(outputLocation, idsFile, namesFile, durationFile, sourceUrl, tagsFile, logOutput, logOutputError, OutputType)

			if err != nil {
				errorLog, _ := readFile(logOutputError)
				ErrorLog("FlatSingleDownload had an error", fmt.Sprintf("Failed to download url: %s", sourceUrl), errorLog)
				cleanUopFiles(filesToDelete)
				continue
			}

			if !fileExists(idsFile) ||
				!fileExists(namesFile) ||
				!fileExists(durationFile) {
				// Failed to creat needed files, check errors
				errorLog, _ := readFile(logOutputError)
				ErrorLog("Error Ytdlp did not create needed files", fmt.Sprintf("Failed to download url: %s", sourceUrl), errorLog)
				cleanUopFiles(filesToDelete)
				continue
			}

			id, err := readFile(idsFile)
			name, err := readFile(namesFile)
			duration, err := readFile(durationFile)
			audioFilePath := fmt.Sprintf("%s/%s.opus", outputLocation, id)
			imageFilePath := fmt.Sprintf("%s/%s.jpg", outputLocation, id)
			tags, err := readFile(tagsFile)

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

			err = db.NewBeatEntry(&rawAudio, name, name, tags, audioPublicUrl.SignedURL, thumbnailPublicUrl.SignedURL)

			if err != nil {
				ErrorLog("Failed to create a new Beat entry", sourceUrl, err.Error())
				cleanUopFiles(filesToDelete)
				continue
			}

		} else {
			// Playlist
			_, err := FlatPlaylistDownload(idsFile, namesFile, durationFile, playlistTitleFile, playlistIdFile, sourceUrl, logOutput, logOutputError)

			if err != nil {
				errorLog, _ := readFile(logOutputError)
				ErrorLog("FlatPlaylistDownload had an error", fmt.Sprintf("Failed to download playlist url: %s", sourceUrl), errorLog)
				cleanUopFiles(filesToDelete)
				continue
			}

			if !fileExists(idsFile) ||
				!fileExists(namesFile) ||
				!fileExists(durationFile) ||
				!fileExists(playlistIdFile) ||
				!fileExists(playlistTitleFile) {
				// Failed to creat needed files, check errors
				errorLog, _ := readFile(logOutputError)
				ErrorLog("Error Ytdlp did not create needed files", fmt.Sprintf("Failed to download playlist url: %s", sourceUrl), errorLog)
				cleanUopFiles(filesToDelete)
				continue
			}

			ids, _ := readLines(idsFile)
			// names, _ := readLines(namesFile)
			// durations, _ := readLines(durationFile)
			// playlistTitles, _ := readLines(playlistTitleFile)
			// playlistIds, _ := readLines(playlistIdFile)

			// Create / Check if beatmix exists
			// Update if it already exist by rerunning
			// In this case video archive would come in handy, or... filter out existing ones using inmem cache,db,file?

			for id := range ids {

				sourceUrlPlaylist := fmt.Sprintf("https://www.youtube.com/watch?v=%s", ids[id])

				_, err := FlatSingleDownload(outputLocation, idsFile, namesFile, durationFile, sourceUrlPlaylist, tagsFile, logOutput, logOutputError, OutputType)

				if err != nil {
					errorLog, _ := readFile(logOutputError)
					ErrorLog("FlatSingleDownload had an error", fmt.Sprintf("Failed to download url: %s", sourceUrl), errorLog)
					cleanUopFiles(filesToDelete)
					continue
				}

				if !fileExists(idsFile) ||
					!fileExists(namesFile) ||
					!fileExists(durationFile) {
					// Failed to creat needed files, check errors
					errorLog, _ := readFile(logOutputError)
					ErrorLog("Error Ytdlp did not create needed files", fmt.Sprintf("Failed to download url: %s", sourceUrl), errorLog)
					cleanUopFiles(filesToDelete)
					continue
				}

				id, err := readFile(idsFile)
				name, err := readFile(namesFile)
				duration, err := readFile(durationFile)
				audioFilePath := fmt.Sprintf("%s/%s.opus", outputLocation, id)
				imageFilePath := fmt.Sprintf("%s/%s.jpg", outputLocation, id)
				tags, err := readFile(tagsFile)

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

				err = db.NewBeatEntry(&rawAudio, name, name, tags, audioPublicUrl.SignedURL, thumbnailPublicUrl.SignedURL)

				if err != nil {
					ErrorLog("Failed to create a new Beat entry", sourceUrl, err.Error())
					cleanUopFiles(filesToDelete)
					continue
				}

				// Update database
				// BearMixBeat, insert BeatMixId, BeatMix
			}

		}

		// Clean up files
		cleanUopFiles(filesToDelete)
	}
}
