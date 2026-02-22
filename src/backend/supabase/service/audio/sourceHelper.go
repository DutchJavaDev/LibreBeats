package main

import (
	"fmt"
	"log"
	"os"
)

var cookiesPath = "/app/cookies.txt"

func FlatPlaylistDownload(
	archiveFileName string,
	idsFileName string,
	namesFileName string,
	durationFileName string,
	playlistTitleFileName string,
	playlistIdFileName string,
	url string,
	logOutput string,
	logOutputError string,
) bool {
	Stdout, err := os.Create(logOutput)

	if err != nil {
		fmt.Println(err)
		panic(-65465465)
	}

	Stderr, err := os.Create(logOutputError)

	if err != nil {
		panic(-65324465)
	}

	proc, _err := os.StartProcess(
		"/usr/local/bin/yt-dlp",
		[]string{
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
			"--js-runtimes=deno:/home/admin/.deno/bin",
			"--remote-components=ejs:npm",
			url,
		},
		&os.ProcAttr{
			Files: []*os.File{
				os.Stdin, /// :))))))))))))))))))))))))))))))))
				Stdout,
				Stderr,
			},
		},
	)
	if _err != nil {
		log.Fatal(_err)
	}

	state, err := proc.Wait()

	if err != nil {
		return false
	}

	return state.Success()
}

func FlatSingleDownload(
	archiveFileName string,
	idsFileName string,
	namesFileName string,
	durationFileName string,
	playlistTitleFileName string,
	playlistIdFileName string,
	url string,
	logOutput string,
	logOutputError string,
	storageFolderName string,
	fileExtension string,
) bool {

	Stdout, err := os.OpenFile(logOutput, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)

	if err != nil {
		panic(-65465465)
	}

	Stderr, err := os.OpenFile(logOutputError, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)

	if err != nil {
		panic(-65324465)
	}

	proc, _err := os.StartProcess(
		"/usr/local/bin/yt-dlp",
		[]string{
			"yt-dlp",
			"--force-ipv4",
			"--write-thumbnail",
			"--extract-audio",
			"--audio-quality=0",
			fmt.Sprintf("--audio-format=%s", fileExtension),
			"--convert-thumbnails=jpg",
			"--force-ipv4",
			"--downloader=aria2c",
			"--no-keep-video",
			"--downloader-args=aria2c:-x 16 -s 16 -j 16",
			"--print-to-file", "%(id)s", idsFileName,
			"--print-to-file", "%(title)s", namesFileName,
			"--print-to-file", "%(duration)s", durationFileName,
			"--output", "/%(id)s.%(ext)s",
			"--concurrent-fragments=20",
			"--ignore-errors",
			fmt.Sprintf("--download-archive=%s", archiveFileName),
			"--extractor-args=youtube:player_js_variant=tv",
			fmt.Sprintf("--cookies=%s", cookiesPath),
			"--js-runtimes=deno:/home/admin/.deno/bin",
			"--remote-components=ejs:npm",
			url,
		},
		&os.ProcAttr{
			Files: []*os.File{
				os.Stdin, /// :))))))))))))))))))))))))))))))))
				Stdout,
				Stderr,
			},
		},
	)
	if _err != nil {
		log.Fatal(_err)
	}

	state, err := proc.Wait()

	if err != nil {
		return false
	}

	return state.Success()
}
