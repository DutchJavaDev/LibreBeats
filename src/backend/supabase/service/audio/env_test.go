package main

import (
	"testing"
)

func TestCreateQueueListenerRequiresEnv(t *testing.T) {
	t.Setenv("POSTGRES_BACKEND_URL", "")
	t.Setenv("QUEUE_NAME", "")

	defer func() {
		if recover() == nil {
			t.Fatal("expected panic when env vars are missing")
		}
	}()
	createQueueListener()
}

func TestCreateQueueListenerWithEnv(t *testing.T) {
	t.Setenv("POSTGRES_BACKEND_URL", "postgres://localhost:5432/postgres")
	t.Setenv("QUEUE_NAME", "audiopipe-input")

	ql := createQueueListener()
	if ql.ConnectionString == "" || ql.QueueName != "audiopipe-input" {
		t.Fatalf("unexpected listener: %+v", ql)
	}
}

func TestNewLibreDbRequiresEnv(t *testing.T) {
	t.Setenv("POSTGRES_BACKEND_URL", "")

	defer func() {
		if recover() == nil {
			t.Fatal("expected panic when POSTGRES_BACKEND_URL is missing")
		}
	}()
	NewLibreDb()
}

func TestNewStorageServiceRequiresEnv(t *testing.T) {
	t.Setenv("STORAGE_URL", "")
	t.Setenv("STORAGE_KEY", "")
	t.Setenv("AUDIO_BUCKET_ID", "")
	t.Setenv("IMAGE_BUCKET_ID", "")

	defer func() {
		if recover() == nil {
			t.Fatal("expected panic when storage env vars are missing")
		}
	}()
	NewStorageService()
}
