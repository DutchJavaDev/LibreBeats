package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestEnsureDir(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	newDir := filepath.Join(dir, "sessions", "run_1")

	if err := ensureDir(newDir); err != nil {
		t.Fatalf("ensureDir new path: %v", err)
	}
	if !pathExists(newDir) {
		t.Fatal("expected directory to exist")
	}

	// Existing directory should not error.
	if err := ensureDir(newDir); err != nil {
		t.Fatalf("ensureDir existing path: %v", err)
	}

	// File at path should error.
	filePath := filepath.Join(dir, "not-a-dir")
	if err := os.WriteFile(filePath, []byte("x"), 0o644); err != nil {
		t.Fatalf("write file: %v", err)
	}
	if err := ensureDir(filePath); err == nil {
		t.Fatal("expected error when path is a file")
	}
}

func TestTryCreateDirectory(t *testing.T) {
	t.Parallel()

	dir := filepath.Join(t.TempDir(), "nested")
	if !tryCreateDirectory(dir) {
		t.Fatal("tryCreateDirectory returned false for valid path")
	}
	if !pathExists(dir) {
		t.Fatal("directory was not created")
	}
}

func TestFileExistsAndReadFile(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	path := filepath.Join(dir, "ids.txt")
	content := "  dQw4w9WgXcQ  \n"

	if fileExists(path) {
		t.Fatal("file should not exist yet")
	}

	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write file: %v", err)
	}

	if !fileExists(path) {
		t.Fatal("file should exist")
	}

	got, err := readFile(path)
	if err != nil {
		t.Fatalf("readFile: %v", err)
	}
	if got != "dQw4w9WgXcQ" {
		t.Fatalf("readFile = %q, want trimmed content", got)
	}
}

func TestReadLines(t *testing.T) {
	t.Parallel()

	path := filepath.Join(t.TempDir(), "lines.txt")
	if err := os.WriteFile(path, []byte("one\ntwo\nthree\n"), 0o644); err != nil {
		t.Fatalf("write file: %v", err)
	}

	lines, err := readLines(path)
	if err != nil {
		t.Fatalf("readLines: %v", err)
	}
	if len(lines) != 3 || lines[0] != "one" || lines[2] != "three" {
		t.Fatalf("readLines = %#v", lines)
	}
}

func TestExistInArchive(t *testing.T) {
	t.Parallel()

	path := filepath.Join(t.TempDir(), "archive.txt")
	archive := "youtube dQw4w9WgXcQ\nyoutube otherId\n"
	if err := os.WriteFile(path, []byte(archive), 0o644); err != nil {
		t.Fatalf("write archive: %v", err)
	}

	if !existInArchive(path, "dQw4w9WgXcQ") {
		t.Fatal("expected id to exist in archive")
	}
	if existInArchive(path, "missing") {
		t.Fatal("expected unknown id not to exist in archive")
	}
}

func TestPathExists(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	if !pathExists(dir) {
		t.Fatal("temp dir should exist")
	}
	if pathExists(filepath.Join(dir, "missing")) {
		t.Fatal("missing path should not exist")
	}
}
