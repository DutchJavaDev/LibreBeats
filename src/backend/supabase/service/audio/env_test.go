package main

import (
	"context"
	"testing"
)

func TestInitDBPoolRequiresEnv(t *testing.T) {
	CloseDBPool()
	t.Setenv("POSTGRES_BACKEND_URL", "")

	err := InitDBPool(context.Background())
	if err == nil {
		t.Fatal("expected error when POSTGRES_BACKEND_URL is missing")
	}
}

func TestCreateQueueListenerRequiresEnv(t *testing.T) {
	CloseDBPool()
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
	CloseDBPool()
	t.Setenv("POSTGRES_BACKEND_URL", "postgres://localhost:5432/postgres")
	t.Setenv("QUEUE_NAME", "audiopipe-input")

	if err := InitDBPool(context.Background()); err != nil {
		t.Fatalf("InitDBPool: %v", err)
	}
	defer CloseDBPool()

	ql := createQueueListener()
	if ql.pool == nil || ql.QueueName != "audiopipe-input" {
		t.Fatalf("unexpected listener: %+v", ql)
	}
}

func TestNewLibreDbRequiresPool(t *testing.T) {
	CloseDBPool()

	_, err := NewLibreDb()
	if err == nil {
		t.Fatal("expected error when pool is not initialized")
	}
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
