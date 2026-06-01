package main

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"
)

func tryCreateDirectory(path string) bool {
	err := ensureDir(path)

	if err != nil {
		ErrorLog("Failed to create directory", "tryCreateDirectory", err.Error())
		return false
	}

	return true
}

func ensureDir(dirName string) error {
	info, err := os.Stat(dirName)
	if err == nil {
		if !info.IsDir() {
			return errors.New("path exists but is not a directory")
		}
		return nil
	}
	if !os.IsNotExist(err) {
		return err
	}
	return os.MkdirAll(dirName, 0o755)
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

func listenForMessage(queue *QueueListener) (*AudioPipeQueueMessage, error) {
	audioQueueMessage, err := queue.Pop()

	if err != nil || audioQueueMessage == nil {
		//ErrorLog(err)
		sleep()
		return nil, err
	}

	return audioQueueMessage, nil
}

func createQueueListener() *QueueListener {
	connectionString := os.Getenv("POSTGRES_BACKEND_URL")
	queueName := os.Getenv("QUEUE_NAME")

	if connectionString == "" {
		panic("POSTGRES_BACKEND_URL environment variable is not set")
	}

	if queueName == "" {
		panic("QUEUE_NAME environment variable is not set")
	}

	return &QueueListener{
		ConnectionString: connectionString,
		QueueName:        queueName,
	}
}

func sleep() {
	fmt.Printf("Sleeping for %d seconds...\n", SleepTimeInSeconds)
	time.Sleep(SleepTimeInSeconds * time.Second)
}

func ErrorLog(title string, outputlog string, errorOutput string) {
	log, _ := getLogger().CreateNewLog(fmt.Sprintf("Error: %s", title))
	log.Output = &outputlog
	log.ErrorOutput = &errorOutput
	log.ProgressState = int(Failed)
	log.FinishedAtUtc = time.Now()
	getLogger().UpdateLog(&log)
	fmt.Println(title)
}

func existInArchive(path string, id string) bool {
	lines, err := readLines(path)

	if err != nil {
		panic(-654654)
	}

	for line := range lines {
		if strings.Contains(lines[line], fmt.Sprintf("youtube %s", id)) {
			return true
		}
	}

	return false
}
