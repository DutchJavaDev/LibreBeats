package main

import (
	"errors"
	"fmt"
	"os"
	"regexp"
	"strconv"
)

const (
	defaultQueueVTSeconds  = 600
	defaultQueueMaxReads   = 5
	defaultDLQQueueName    = "audiopipe-dlq"
)

var queueNamePattern = regexp.MustCompile(`^[a-zA-Z0-9_-]+$`)

type queueConfig struct {
	queueName            string
	dlqName              string
	visibilityTimeoutSec int
	maxReadCount         int64
}

func loadQueueConfig() (queueConfig, error) {
	queueName := os.Getenv("QUEUE_NAME")
	if queueName == "" {
		return queueConfig{}, errors.New("QUEUE_NAME environment variable is not set")
	}
	if err := validateQueueName(queueName); err != nil {
		return queueConfig{}, err
	}

	dlqName := os.Getenv("QUEUE_DLQ_NAME")
	if dlqName == "" {
		dlqName = defaultDLQQueueName
	}
	if err := validateQueueName(dlqName); err != nil {
		return queueConfig{}, fmt.Errorf("QUEUE_DLQ_NAME: %w", err)
	}

	vt := defaultQueueVTSeconds
	if raw := os.Getenv("QUEUE_VISIBILITY_TIMEOUT_SEC"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed < 1 {
			return queueConfig{}, fmt.Errorf("invalid QUEUE_VISIBILITY_TIMEOUT_SEC: %q", raw)
		}
		vt = parsed
	}

	maxReads := int64(defaultQueueMaxReads)
	if raw := os.Getenv("QUEUE_MAX_READ_COUNT"); raw != "" {
		parsed, err := strconv.ParseInt(raw, 10, 64)
		if err != nil || parsed < 1 {
			return queueConfig{}, fmt.Errorf("invalid QUEUE_MAX_READ_COUNT: %q", raw)
		}
		maxReads = parsed
	}

	return queueConfig{
		queueName:            queueName,
		dlqName:              dlqName,
		visibilityTimeoutSec: vt,
		maxReadCount:         maxReads,
	}, nil
}

func validateQueueName(name string) error {
	if !queueNamePattern.MatchString(name) {
		return fmt.Errorf("invalid queue name %q", name)
	}
	return nil
}
