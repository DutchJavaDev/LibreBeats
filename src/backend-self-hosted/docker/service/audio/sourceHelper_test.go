package main

import (
	"strings"
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

// Pins the options the Windows CLI relies on too, so the two stay in step.
func TestSingleArgsMatchCli(t *testing.T) {
	t.Parallel()

	args := singleArgs("/tmp/out", "ids.txt", "names.txt", "durations.txt", "https://www.youtube.com/watch?v=abc123", "tags.txt", "opus")

	count := map[string]int{}
	for _, arg := range args {
		count[arg]++
	}
	for _, once := range []string{"--force-ipv4", "--js-runtimes=deno", "--remote-components=ejs:npm", "--audio-format=opus", "-f"} {
		if count[once] != 1 {
			t.Fatalf("%s appears %d times, want 1", once, count[once])
		}
	}
	if count["--extractor-args=youtube:player_js_variant=tv;player_client=default,-web_embedded"] != 1 {
		t.Fatal("extractor args must exclude the web_embedded client (needs a PO token, 403 without one)")
	}
	for _, arg := range args {
		if strings.HasPrefix(arg, "--downloader") {
			t.Fatalf("argv contains %q; aria2c fails on YouTube with exit 22", arg)
		}
	}
}
