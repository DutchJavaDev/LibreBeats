package main

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"strings"
)

func tryCreateDirectory(path string) bool {
	err := ensureDir(path)

	if err != nil {
		ErrorLog("Failed to create directory", "", err.Error())
		return false
	}

	return true
}

func ensureDir(dirName string) error {
	err := os.Mkdir(dirName, os.ModeDir)
	if err == nil {
		return nil
	}
	if os.IsExist(err) {
		// check that the existing path is a directory
		info, err := os.Stat(dirName)
		if err != nil {
			return err
		}
		if !info.IsDir() {
			return errors.New("path exists but is not a directory")
		}
		return nil
	}
	return err
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	// No error, file exists
	return err == nil
}

// readLines reads a whole file into memory
// and returns a slice of its lines.
func readLines(path string) ([]string, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var lines []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}
	return lines, scanner.Err()
}

func readFile(path string) (string, error) {
	bytes, err := os.ReadFile(path)

	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(bytes)), nil
}

func pathExists(path string) bool {
	info, err := os.Stat(path)
	if os.IsNotExist(err) {
		return false
	}
	return err == nil && (info.IsDir())
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
