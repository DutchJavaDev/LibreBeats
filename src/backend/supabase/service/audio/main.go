package main

import (
	"fmt"
	"os"
	"strconv"
)

const (
	SleepTimeInSeconds = 5
	StorageLocation    = "/app/sessions"
	OutputType         = "opus"
	ArchiveLocation    = "/etc/librebeats/46asd46as1das"
)

var logger IAudioOutputLogger

func main() {
	l := NewYtdlpLogger()
	logger = &l

	if !fileExists(ArchiveLocation) {
		err := os.WriteFile(ArchiveLocation, []byte(""), 0666)

		if err != nil {
			panic(err)
		}
	}

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

		sourceUrl, err := parseAudioPipeURL(audioQueueMessage.Message)

		if err != nil {
			ErrorLog(fmt.Sprintf("Failed to unmarshal message body for message id: %d", audioQueueMessage.Id), string(audioQueueMessage.Message), fmt.Sprintf("Error: %s", err.Error()))
			continue
		}

		isPlaylist := isYouTubePlaylistURL(sourceUrl)

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
			_, err := FlatSingleDownload(ArchiveLocation, outputLocation, idsFile, namesFile, durationFile, sourceUrl, tagsFile, logOutput, logOutputError, OutputType)

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

			err, _ = db.NewBeatEntry(&rawAudio, name, name, tags, audioPublicUrl.SignedURL, thumbnailPublicUrl.SignedURL)

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
			names, _ := readLines(namesFile)
			durations, _ := readLines(durationFile)
			playlistTitles, _ := readLines(playlistTitleFile)
			playlistIds, _ := readLines(playlistIdFile)

			// Check if beatmix exists
			err, beatmix := db.GetBeatMixByName(playlistTitles[0])

			if err != nil || beatmix.Id == -1 {
				// Does not exists
				// create instead
				beatmix = BeatMix{}

				beatmix.Title = playlistTitles[0]

				// ??????
				imageFilePath := fmt.Sprintf("/app/%s [%s].jpg", playlistTitles[0], playlistIds[0])

				// upload
				imageUploadResponse, err := storage.UploadImageFile(imageFilePath, fmt.Sprintf("%s.jpeg", playlistIds[0]))

				// If this fails because its unable to download the file
				// Use a placeholder
				if err != nil {
					ErrorLog(fmt.Sprintf("Failed to upload thumbnail file %s file for message id: %d", imageFilePath,
						audioQueueMessage.Id),
						imageUploadResponse.Error,
						fmt.Sprintf("Error: %s", err.Error()))
					beatmix.ThumbnailURL = "404" // TODO set a default,
				} else {
					beatmix.ThumbnailURL = storage.GetImagePublicUrl(imageUploadResponse.Key).SignedURL
				}

				// Insert BeatMixBeat,
				err = db.NewBeatMixEntry(&beatmix)

				if err != nil {
					ErrorLog("Failed to insert new Beatmix", fmt.Sprintf("Insert failed: %s", sourceUrl), err.Error())
					return
				}
			}

			// Create
			for id := range ids {

				sourceUrlPlaylistItem := fmt.Sprintf("https://www.youtube.com/watch?v=%s", ids[id])

				outputLocationIsolated := fmt.Sprintf("%s/%s", outputLocation, strconv.Itoa(id))

				_, err := FlatSingleDownload(ArchiveLocation, outputLocationIsolated, idsFile, namesFile, durationFile, sourceUrlPlaylistItem, tagsFile, logOutput, logOutputError, OutputType)

				if err != nil {
					errorLog, _ := readFile(logOutputError)
					ErrorLog("FlatSingleDownload had an error", fmt.Sprintf("Failed to download url: %s", sourceUrl), errorLog)
					cleanUopFiles(filesToDelete)
					continue
				}

				if !fileExists(idsFile) ||
					!fileExists(namesFile) ||
					!fileExists(durationFile) ||
					!fileExists(tagsFile) {
					// Failed to creat needed files, check errors
					errorLog, _ := readFile(logOutputError)
					ErrorLog("Error Ytdlp did not create needed files", fmt.Sprintf("Failed to download url: %s", sourceUrl), errorLog)
					cleanUopFiles(filesToDelete)
					continue
				}

				tags, err := readLines(tagsFile)
				audioFilePath := fmt.Sprintf("%s/%s.opus", outputLocationIsolated, ids[id])
				imageFilePath := fmt.Sprintf("%s/%s.jpg", outputLocationIsolated, ids[id])

				// Upload to storage
				audioUploadResponse, err := storage.UploadAudioFile(audioFilePath, fmt.Sprintf("%s.opus", ids[id]))

				if err != nil {
					ErrorLog(fmt.Sprintf("Failed to upload audio file %s for message id: %d", audioFilePath, audioQueueMessage.Id),
						string(audioQueueMessage.Message),
						fmt.Sprintf("Error: %s", err.Error()))
					cleanUopFiles(filesToDelete)
					continue
				}

				imageUploadResponse, err := storage.UploadImageFile(imageFilePath, fmt.Sprintf("%s.jpeg", ids[id]))

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
				_dur, err := strconv.Atoi(durations[id])
				rawBeat, err := db.NewRawAudioEntry(sourceUrlPlaylistItem, audioStorageLocation, imageStorageLocation, _dur)

				if err != nil {
					ErrorLog("Failed to create new RawAudio entry", sourceUrlPlaylistItem, err.Error())
					cleanUopFiles(filesToDelete)
					continue
				}

				audioPublicUrl := storage.GetAudioPublicUrl(audioStorageLocation)
				thumbnailPublicUrl := storage.GetImagePublicUrl(imageStorageLocation)

				err, beatId := db.NewBeatEntry(&rawBeat, names[id], names[id], tags[id], audioPublicUrl.SignedURL, thumbnailPublicUrl.SignedURL)

				if err != nil || beatId == -1 {
					ErrorLog("Failed to create a new Beat entry", sourceUrlPlaylistItem, err.Error())
					cleanUopFiles(filesToDelete)
					continue
				}

				// Update database
				// Insert BeatMixId,
				// Insert BeatMix

				err, beatmix = db.GetBeatMixByName(playlistTitles[0])

				if err != nil {
					ErrorLog("Failed to fetch new Beatmix", fmt.Sprintf("Fetch failed: %s", sourceUrl), err.Error())
					cleanUopFiles(filesToDelete)
					continue
				}

				err = db.NewBeatMixBeatEntry(beatmix.Id, beatId)

				if err != nil { // BUGGGGGGGGGGGGGG
					ErrorLog(fmt.Sprintf("Failed to create a new BeatMixBeat entry %d %d", beatmix.Id, beatId), sourceUrlPlaylistItem, err.Error())
					cleanUopFiles(filesToDelete)
					continue
				}
			}

		}

		// Clean up files
		cleanUopFiles(filesToDelete)
	}
}
