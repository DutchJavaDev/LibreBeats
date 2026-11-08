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
	t.Setenv("STORAGE_PUBLIC_URL", "")

	defer func() {
		if recover() == nil {
			t.Fatal("expected panic when storage env vars are missing")
		}
	}()
	NewStorageService()
}

func TestGetPublicUrlUsesPublicBaseUrl(t *testing.T) {
	t.Setenv("STORAGE_URL", "http://kong:8000/storage/v1")
	t.Setenv("STORAGE_KEY", "key")
	t.Setenv("AUDIO_BUCKET_ID", "audio-files")
	t.Setenv("IMAGE_BUCKET_ID", "image-files")
	t.Setenv("STORAGE_PUBLIC_URL", "https://beats.example.com/")

	s := NewStorageService()

	if got := s.GetAudioPublicUrl("abc.opus").SignedURL; got != "https://beats.example.com/storage/v1/object/public/audio-files/abc.opus?download=true" {
		t.Fatalf("audio url: %q", got)
	}
	if got := s.GetImagePublicUrl("thumb.jpeg").SignedURL; got != "https://beats.example.com/storage/v1/object/public/image-files/thumb.jpeg?download=true" {
		t.Fatalf("image url: %q", got)
	}
}
