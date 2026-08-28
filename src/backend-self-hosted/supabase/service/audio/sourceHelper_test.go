package main

import (
	"testing"
)

// shared checks for both builders, the url must stay behind the "--" so
// yt-dlp never reads it as a flag
func checkArgvShape(t *testing.T, name string, args []string, url string) {
	t.Helper()

	if args[0] != "yt-dlp" {
		t.Fatalf("%s argv[0] = %q, want %q", name, args[0], "yt-dlp")
	}
	if got := args[len(args)-1]; got != url {
		t.Fatalf("%s last element = %q, want %q", name, got, url)
	}
	if got := args[len(args)-2]; got != "--" {
		t.Fatalf("%s second-to-last element = %q, want %q", name, got, "--")
	}
	for i, arg := range args[:len(args)-2] {
		if arg == url {
			t.Fatalf("%s argv[%d] = %q, url must not appear before the --", name, i, arg)
		}
	}
}

func TestPlaylistArgs(t *testing.T) {
	t.Parallel()

	urls := []string{
		"https://www.youtube.com/playlist?list=PLtest",
		"--exec=id",
	}

	for _, url := range urls {
		args := playlistArgs("ids.txt", "names.txt", "durations.txt", "playlistTitle.txt", "playlistId.txt", url)
		checkArgvShape(t, "playlistArgs", args, url)
	}
}

func TestSingleArgs(t *testing.T) {
	t.Parallel()

	urls := []string{
		"https://www.youtube.com/watch?v=abc123",
		"--exec=id",
	}

	for _, url := range urls {
		args := singleArgs("/tmp/out", "ids.txt", "names.txt", "durations.txt", url, "tags.txt", "opus")
		checkArgvShape(t, "singleArgs", args, url)
	}
}
