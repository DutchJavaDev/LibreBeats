package main

import (
	"fmt"
	"os"
)

var cookiesPath = "/app/cookies.txt"

// argv builders split out so tests can check the shape without spawning
// anything, the "--" keeps a hostile url from being read as a flag
func playlistArgs(idsFileName, namesFileName, durationFileName, playlistTitleFileName, playlistIdFileName, url string) []string {
	return []string{
		"yt-dlp",
		"--force-ipv4",
		"--no-keep-video",
		"--skip-download",
		"--flat-playlist",
		"--write-thumbnail",
		"--print-to-file", "%(id)s", idsFileName,
		"--print-to-file", "%(title)s", namesFileName,
		"--print-to-file", "%(duration)s", durationFileName,
		"--print-to-file", "%(playlist_id)s", playlistIdFileName,
		"--print-to-file", "%(playlist_title)s", playlistTitleFileName,
		"--ignore-errors",
		"--extractor-args=youtube:player_js_variant=tv",
		fmt.Sprintf("--cookies=%s", cookiesPath),
		"--js-runtimes=deno:/usr/bin",
		"--remote-components=ejs:npm",
		"--",
		url,
	}
}

// Same options, in the same order, as the Windows CLI tools/ytdlp-audio.ps1
// (Get-SingleArgs and Get-SharedArgs). Keep the two in step.
func singleArgs(outputLocation, idsFileName, namesFileName, durationFileName, url, tagsFileName, fileExtension string) []string {
	return []string{
		"yt-dlp",
		"--write-thumbnail",
		"--extract-audio",
		"--audio-quality=0",
		fmt.Sprintf("--audio-format=%s", fileExtension),
		"--convert-thumbnails=jpg",
		"--no-keep-video",
		"--print-to-file", "%(id)s", idsFileName,
		"--print-to-file", "%(title)s", namesFileName,
		"--print-to-file", "%(duration)s", durationFileName,
		"--print-to-file", "%(tags)s", tagsFileName,
		"--output", outputLocation + "/%(id)s.%(ext)s",
		"--concurrent-fragments=20",
		"--ignore-errors",
		"--force-ipv4",
		"--extractor-args=youtube:player_js_variant=tv",
		fmt.Sprintf("--cookies=%s", cookiesPath),
		"--js-runtimes=deno",
		"--remote-components=ejs:npm",
		"--",
		url,
	}
}

func FlatPlaylistDownload(
	idsFileName string,
	namesFileName string,
	durationFileName string,
	playlistTitleFileName string,
	playlistIdFileName string,
	url string,
	logOutput string,
	logOutputError string,
) (bool, error) {
	Stdout, err := os.Create(logOutput)

	if err != nil {
		fmt.Println(err.Error())
		return false, err
	}
	defer Stdout.Close()

	Stderr, err := os.Create(logOutputError)

	if err != nil {
		fmt.Println(err.Error())
		return false, err
	}
	defer Stderr.Close()

	proc, _err := os.StartProcess(
		"/usr/bin/yt-dlp",
		playlistArgs(idsFileName, namesFileName, durationFileName, playlistTitleFileName, playlistIdFileName, url),
		&os.ProcAttr{
			Files: []*os.File{
				os.Stdin, /// :))))))))))))))))))))))))))))))))
				Stdout,
				Stderr,
			},
		},
	)
	if _err != nil {
		fmt.Println(_err.Error())
		return false, _err
	}

	state, err := proc.Wait()

	if err != nil {
		return false, err
	}

	if !state.Success() {
		return false, fmt.Errorf("yt-dlp exited with %s", state.String())
	}

	return true, nil
}

func FlatSingleDownload(
	archiveFileName string,
	outputLocation string,
	idsFileName string,
	namesFileName string,
	durationFileName string,
	url string,
	tagsFileName string,
	logOutput string,
	logOutputError string,
	fileExtension string,
) (bool, error) {

	Stdout, err := os.OpenFile(logOutput, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)

	if err != nil {
		fmt.Println(err.Error())
		return false, err
	}
	defer Stdout.Close()

	Stderr, err := os.OpenFile(logOutputError, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)

	if err != nil {
		fmt.Println(err.Error())
		return false, err
	}
	defer Stderr.Close()

	proc, _err := os.StartProcess(
		"/usr/bin/yt-dlp",
		singleArgs(outputLocation, idsFileName, namesFileName, durationFileName, url, tagsFileName, fileExtension),
		&os.ProcAttr{
			Files: []*os.File{
				os.Stdin, /// :))))))))))))))))))))))))))))))))
				Stdout,
				Stderr,
			},
		},
	)

	if _err != nil {
		return false, _err
	}

	state, err := proc.Wait()

	if err != nil {
		return false, err
	}

	if !state.Success() {
		return false, fmt.Errorf("yt-dlp exited with %s", state.String())
	}

	return true, nil
}
