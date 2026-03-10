package main

import (
	"os"

	storage "github.com/supabase-community/storage-go"
)

type IStorageService interface {
	UploadAudioFile(filePath string, fileName string) (storage.FileUploadResponse, error)
	UploadImageFile(filePath string, fileName string) (storage.FileUploadResponse, error)
}

type StorageService struct {
	IStorageService
	client *storage.Client
}

func NewStorageService() *StorageService {
	// Will throw an error if its missing a method implementation from interface
	// will throw a compile time error
	var _ IStorageService = (*StorageService)(nil)

	storageUrl := os.Getenv("STORAGE_URL")

	if storageUrl == "" {
		panic("STORAGE_URL environment variable is not set")
	}

	storageKey := os.Getenv("STORAGE_KEY")

	if storageKey == "" {
		panic("STORAGE_KEY environment variable is not set")
	}

	storageClient := storage.NewClient(storageUrl, storageKey, nil)

	return &StorageService{
		client: storageClient,
	}
}

func (s *StorageService) UploadAudioFile(filePath string, fileName string) (storage.FileUploadResponse, error) {
	// Open the file you want to upload
	file, err := os.Open(filePath)
	if err != nil {
		return storage.FileUploadResponse{}, err
	}
	defer file.Close()

	// Upload the file to the specified bucket and path
	contentType := "audio/ogg"
	upsert := true
	options := &storage.FileOptions{
		ContentType: &contentType,
		Upsert:      &upsert,
	}
	response, err := s.client.UploadFile("audio-files", fileName, file, *options)

	if err != nil {
		return storage.FileUploadResponse{}, err
	}
	return response, nil
}

func (s *StorageService) UploadImageFile(filePath string, fileName string) (storage.FileUploadResponse, error) {
	// Open the file you want to upload
	file, err := os.Open(filePath)
	if err != nil {
		return storage.FileUploadResponse{}, err
	}
	defer file.Close()

	// Upload the file to the specified bucket and path
	contentType := "image/jpeg"
	upsert := true
	options := &storage.FileOptions{
		ContentType: &contentType,
		Upsert:      &upsert,
	}
	response, err := s.client.UploadFile("image-files", fileName, file, *options)

	if err != nil {
		return storage.FileUploadResponse{}, err
	}
	return response, nil
}
