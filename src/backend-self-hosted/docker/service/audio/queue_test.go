package main

import (
	"errors"
	"testing"
)

func TestValidateQueueName(t *testing.T) {
	t.Parallel()

	if err := validateQueueName("audiopipe-input"); err != nil {
		t.Fatalf("valid name rejected: %v", err)
	}
	if err := validateQueueName("bad name"); err == nil {
		t.Fatal("expected invalid queue name error")
	}
}

func TestLoadQueueConfigDefaults(t *testing.T) {
	t.Setenv("QUEUE_NAME", "audiopipe-input")
	t.Setenv("QUEUE_DLQ_NAME", "")
	t.Setenv("QUEUE_VISIBILITY_TIMEOUT_SEC", "")
	t.Setenv("QUEUE_MAX_READ_COUNT", "")

	cfg, err := loadQueueConfig()
	if err != nil {
		t.Fatalf("loadQueueConfig: %v", err)
	}
	if cfg.dlqName != defaultDLQQueueName {
		t.Fatalf("dlqName = %q, want %q", cfg.dlqName, defaultDLQQueueName)
	}
	if cfg.visibilityTimeoutSec != defaultQueueVTSeconds {
		t.Fatalf("vt = %d, want %d", cfg.visibilityTimeoutSec, defaultQueueVTSeconds)
	}
	if cfg.maxReadCount != int64(defaultQueueMaxReads) {
		t.Fatalf("maxReadCount = %d, want %d", cfg.maxReadCount, defaultQueueMaxReads)
	}
}

func TestIsPermanentQueueError(t *testing.T) {
	t.Parallel()

	if !isPermanentQueueError(ErrPermanentMessage) {
		t.Fatal("expected permanent error")
	}
	if isPermanentQueueError(errors.New("transient")) {
		t.Fatal("expected transient error")
	}
}

func TestWrapDLQPayload(t *testing.T) {
	t.Parallel()

	msg := &AudioPipeQueueMessage{
		Id:      42,
		ReadCT:  3,
		Message: []byte(`{"url":"https://example.com"}`),
	}
	payload, err := wrapDLQPayload(msg, ErrPermanentMessage)
	if err != nil {
		t.Fatalf("wrapDLQPayload: %v", err)
	}
	if len(payload) == 0 {
		t.Fatal("expected non-empty payload")
	}
}
