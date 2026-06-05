package main

import (
	"fmt"
	"path/filepath"
	"strconv"
)

func processQueueMessage(msg *AudioPipeQueueMessage, db LibreDb, storage *StorageService) error {
	sourceURL, err := parseAudioPipeURL(msg.Message)
	if err != nil {
		return err
	}

	isPlaylist := isYouTubePlaylistURL(sourceURL)
	outputLocation := fmt.Sprintf("%s/run_%d", StorageLocation, msg.Id)

	if !tryCreateDirectory(StorageLocation) || !tryCreateDirectory(outputLocation) {
		return fmt.Errorf("failed to create session directories for message %d", msg.Id)
	}

	if !isPlaylist {
		return processSingleTrack(msg, db, storage, sourceURL, outputLocation)
	}
	return processPlaylist(msg, db, storage, sourceURL, outputLocation)
}

func processSingleTrack(msg *AudioPipeQueueMessage, db LibreDb, storage *StorageService, sourceURL, outputLocation string) error {
	idsFile := filepath.Join(outputLocation, "ids.txt")
	namesFile := filepath.Join(outputLocation, "names.txt")
	durationFile := filepath.Join(outputLocation, "duration.txt")
	tagsFile := filepath.Join(outputLocation, "tags.txt")
	logOutput := filepath.Join(outputLocation, "output.log")
	logOutputError := filepath.Join(outputLocation, "error.log")

	_, err := FlatSingleDownload(ArchiveLocation, outputLocation, idsFile, namesFile, durationFile, sourceURL, tagsFile, logOutput, logOutputError, OutputType)
	if err != nil {
		errorLog, _ := readFile(logOutputError)
		ErrorLog("FlatSingleDownload had an error", fmt.Sprintf("Failed to download url: %s", sourceURL), errorLog)
		return fmt.Errorf("flat single download: %w", err)
	}

	if !fileExists(idsFile) || !fileExists(namesFile) || !fileExists(durationFile) {
		errorLog, _ := readFile(logOutputError)
		ErrorLog("Error Ytdlp did not create needed files", fmt.Sprintf("Failed to download url: %s", sourceURL), errorLog)
		return fmt.Errorf("yt-dlp missing output files for %s", sourceURL)
	}

	id, err := readFile(idsFile)
	if err != nil {
		return fmt.Errorf("read id file: %w", err)
	}
	name, err := readFile(namesFile)
	if err != nil {
		return fmt.Errorf("read name file: %w", err)
	}
	duration, err := readFile(durationFile)
	if err != nil {
		return fmt.Errorf("read duration file: %w", err)
	}
	tags, err := readFile(tagsFile)
	if err != nil {
		return fmt.Errorf("read tags file: %w", err)
	}

	audioFilePath := filepath.Join(outputLocation, id+".opus")
	imageFilePath := filepath.Join(outputLocation, id+".jpg")

	audioUploadResponse, err := storage.UploadAudioFile(audioFilePath, id+".opus")
	if err != nil {
		ErrorLog(fmt.Sprintf("Failed to upload audio file %s for message id: %d", audioFilePath, msg.Id),
			string(msg.Message), err.Error())
		return fmt.Errorf("upload audio: %w", err)
	}

	imageUploadResponse, err := storage.UploadImageFile(imageFilePath, id+".jpeg")
	if err != nil {
		ErrorLog(fmt.Sprintf("Failed to upload image file %s for message id: %d", imageFilePath, msg.Id),
			imageUploadResponse.Error, err.Error())
		return fmt.Errorf("upload image: %w", err)
	}

	dur, err := strconv.Atoi(duration)
	if err != nil {
		return fmt.Errorf("parse duration: %w", err)
	}

	rawAudio, err := db.NewRawAudioEntry(sourceURL, audioUploadResponse.Key, imageUploadResponse.Key, dur)
	if err != nil {
		ErrorLog("Failed to create new RawAudio entry", sourceURL, err.Error())
		return fmt.Errorf("insert raw beat: %w", err)
	}

	audioPublicURL := storage.GetAudioPublicUrl(audioUploadResponse.Key)
	thumbnailPublicURL := storage.GetImagePublicUrl(imageUploadResponse.Key)

	if err, _ := db.NewBeatEntry(&rawAudio, name, name, tags, audioPublicURL.SignedURL, thumbnailPublicURL.SignedURL); err != nil {
		ErrorLog("Failed to create a new Beat entry", sourceURL, err.Error())
		return fmt.Errorf("insert beat: %w", err)
	}

	return nil
}

func processPlaylist(msg *AudioPipeQueueMessage, db LibreDb, storage *StorageService, sourceURL, outputLocation string) error {
	idsFile := filepath.Join(outputLocation, "ids.txt")
	namesFile := filepath.Join(outputLocation, "names.txt")
	durationFile := filepath.Join(outputLocation, "duration.txt")
	playlistTitleFile := filepath.Join(outputLocation, "playlist_title.txt")
	playlistIdFile := filepath.Join(outputLocation, "playlist_id.txt")
	logOutput := filepath.Join(outputLocation, "output.log")
	logOutputError := filepath.Join(outputLocation, "error.log")

	_, err := FlatPlaylistDownload(idsFile, namesFile, durationFile, playlistTitleFile, playlistIdFile, sourceURL, logOutput, logOutputError)
	if err != nil {
		errorLog, _ := readFile(logOutputError)
		ErrorLog("FlatPlaylistDownload had an error", fmt.Sprintf("Failed to download playlist url: %s", sourceURL), errorLog)
		return fmt.Errorf("flat playlist download: %w", err)
	}

	if !fileExists(idsFile) || !fileExists(namesFile) || !fileExists(durationFile) ||
		!fileExists(playlistIdFile) || !fileExists(playlistTitleFile) {
		errorLog, _ := readFile(logOutputError)
		ErrorLog("Error Ytdlp did not create needed files", fmt.Sprintf("Failed to download playlist url: %s", sourceURL), errorLog)
		return fmt.Errorf("yt-dlp missing playlist metadata for %s", sourceURL)
	}

	ids, err := readLines(idsFile)
	if err != nil {
		return fmt.Errorf("read playlist ids: %w", err)
	}
	names, err := readLines(namesFile)
	if err != nil {
		return fmt.Errorf("read playlist names: %w", err)
	}
	durations, err := readLines(durationFile)
	if err != nil {
		return fmt.Errorf("read playlist durations: %w", err)
	}
	playlistTitles, err := readLines(playlistTitleFile)
	if err != nil {
		return fmt.Errorf("read playlist titles: %w", err)
	}
	playlistIds, err := readLines(playlistIdFile)
	if err != nil {
		return fmt.Errorf("read playlist ids: %w", err)
	}
	if len(ids) == 0 || len(playlistTitles) == 0 || len(playlistIds) == 0 {
		return fmt.Errorf("%w: empty playlist", ErrPermanentMessage)
	}
	if len(names) != len(ids) || len(durations) != len(ids) {
		return fmt.Errorf("playlist metadata line count mismatch")
	}

	mixErr, beatmix := db.GetBeatMixByName(playlistTitles[0])
	if mixErr != nil || beatmix.Id == -1 {
		beatmix = BeatMix{Title: playlistTitles[0]}
		imageFilePath := fmt.Sprintf("/app/%s [%s].jpg", playlistTitles[0], playlistIds[0])

		imageUploadResponse, uploadErr := storage.UploadImageFile(imageFilePath, fmt.Sprintf("%s.jpeg", playlistIds[0]))
		if uploadErr != nil {
			ErrorLog(fmt.Sprintf("Failed to upload thumbnail file %s for message id: %d", imageFilePath, msg.Id),
				imageUploadResponse.Error, uploadErr.Error())
			beatmix.ThumbnailURL = "404"
		} else {
			beatmix.ThumbnailURL = storage.GetImagePublicUrl(imageUploadResponse.Key).SignedURL
		}

		if err := db.NewBeatMixEntry(&beatmix); err != nil {
			ErrorLog("Failed to insert new Beatmix", fmt.Sprintf("Insert failed: %s", sourceURL), err.Error())
			return fmt.Errorf("insert beatmix: %w", err)
		}
	}

	var trackErrors int
	for idx := range ids {
		if err := processPlaylistTrack(msg, db, storage, outputLocation, idx, ids, names, durations, playlistTitles[0]); err != nil {
			fmt.Printf("playlist track %d failed: %v\n", idx, err)
			trackErrors++
		}
	}

	if trackErrors > 0 {
		return fmt.Errorf("playlist processing failed for %d of %d tracks", trackErrors, len(ids))
	}
	return nil
}

func processPlaylistTrack(
	msg *AudioPipeQueueMessage,
	db LibreDb,
	storage *StorageService,
	outputLocation string,
	idx int,
	ids, names, durations []string,
	playlistTitle string,
) error {
	sourceURLItem := fmt.Sprintf("https://www.youtube.com/watch?v=%s", ids[idx])
	outputLocationIsolated := filepath.Join(outputLocation, strconv.Itoa(idx))

	itemIdsFile := filepath.Join(outputLocationIsolated, "ids.txt")
	itemNamesFile := filepath.Join(outputLocationIsolated, "names.txt")
	itemDurationFile := filepath.Join(outputLocationIsolated, "duration.txt")
	itemTagsFile := filepath.Join(outputLocationIsolated, "tags.txt")
	itemLogOutput := filepath.Join(outputLocationIsolated, "output.log")
	itemLogOutputError := filepath.Join(outputLocationIsolated, "error.log")

	if !tryCreateDirectory(outputLocationIsolated) {
		return fmt.Errorf("create track directory")
	}

	_, err := FlatSingleDownload(ArchiveLocation, outputLocationIsolated, itemIdsFile, itemNamesFile, itemDurationFile, sourceURLItem, itemTagsFile, itemLogOutput, itemLogOutputError, OutputType)
	if err != nil {
		errorLog, _ := readFile(itemLogOutputError)
		ErrorLog("FlatSingleDownload had an error", sourceURLItem, errorLog)
		return err
	}

	if !fileExists(itemIdsFile) || !fileExists(itemNamesFile) || !fileExists(itemDurationFile) || !fileExists(itemTagsFile) {
		errorLog, _ := readFile(itemLogOutputError)
		ErrorLog("Error Ytdlp did not create needed files", sourceURLItem, errorLog)
		return fmt.Errorf("missing track output files")
	}

	videoID, err := readFile(itemIdsFile)
	if err != nil {
		return err
	}
	tags, err := readFile(itemTagsFile)
	if err != nil {
		return err
	}

	audioFilePath := filepath.Join(outputLocationIsolated, videoID+".opus")
	imageFilePath := filepath.Join(outputLocationIsolated, videoID+".jpg")

	audioUploadResponse, err := storage.UploadAudioFile(audioFilePath, videoID+".opus")
	if err != nil {
		ErrorLog(fmt.Sprintf("Failed to upload audio for message %d", msg.Id), string(msg.Message), err.Error())
		return err
	}

	imageUploadResponse, err := storage.UploadImageFile(imageFilePath, videoID+".jpeg")
	if err != nil {
		ErrorLog(fmt.Sprintf("Failed to upload image for message %d", msg.Id), imageUploadResponse.Error, err.Error())
		return err
	}

	dur, err := strconv.Atoi(durations[idx])
	if err != nil {
		return err
	}

	rawBeat, err := db.NewRawAudioEntry(sourceURLItem, audioUploadResponse.Key, imageUploadResponse.Key, dur)
	if err != nil {
		ErrorLog("Failed to create new RawAudio entry", sourceURLItem, err.Error())
		return err
	}

	audioPublicURL := storage.GetAudioPublicUrl(audioUploadResponse.Key)
	thumbnailPublicURL := storage.GetImagePublicUrl(imageUploadResponse.Key)

	err, beatID := db.NewBeatEntry(&rawBeat, names[idx], names[idx], tags, audioPublicURL.SignedURL, thumbnailPublicURL.SignedURL)
	if err != nil || beatID == -1 {
		ErrorLog("Failed to create a new Beat entry", sourceURLItem, err.Error())
		return fmt.Errorf("insert beat: %w", err)
	}

	err, beatmix := db.GetBeatMixByName(playlistTitle)
	if err != nil {
		ErrorLog("Failed to fetch Beatmix", playlistTitle, err.Error())
		return err
	}

	if err := db.NewBeatMixBeatEntry(beatID, beatmix.Id); err != nil {
		ErrorLog(fmt.Sprintf("Failed to create BeatMixBeat beat=%d mix=%d", beatID, beatmix.Id), sourceURLItem, err.Error())
		return err
	}

	return nil
}
