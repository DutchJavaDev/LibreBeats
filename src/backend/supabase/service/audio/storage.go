package main

import (
	"os"

	storage "github.com/supabase-community/storage-go"
)

type IStorageService interface {
	EnsureBucketsExists()
	GetAudioPublicUrl(filename string) storage.SignedUrlResponse
	UploadAudioFile(filePath string, fileName string) (storage.FileUploadResponse, error)
	GetImagePublicUrl(filename string) storage.SignedUrlResponse
	UploadImageFile(filePath string, fileName string) (storage.FileUploadResponse, error)
}

type StorageService struct {
	IStorageService
	client        *storage.Client
	audioBucketId string
	imageBucketId string
}

func NewStorageService() *StorageService {
	// Will throw an error if its missing a method implementation from interface
	var _ IStorageService = (*StorageService)(nil)

	storageUrl := os.Getenv("STORAGE_URL")

	if storageUrl == "" {
		panic("STORAGE_URL environment variable is not set")
	}

	storageKey := os.Getenv("STORAGE_KEY")

	if storageKey == "" {
		panic("STORAGE_KEY environment variable is not set")
	}

	audioBucketId := os.Getenv("AUDIO_BUCKET_ID")

	if audioBucketId == "" {
		panic("AUDIO_BUCKET_ID environment variable is not set")
	}

	imageBucketId := os.Getenv("IMAGE_BUCKET_ID")

	if imageBucketId == "" {
		panic("IMAGE_BUCKET_ID environment variable is not set")
	}

	storageClient := storage.NewClient(storageUrl, storageKey, nil)

	return &StorageService{
		client:        storageClient,
		audioBucketId: audioBucketId,
		imageBucketId: imageBucketId,
	}
}

func (s *StorageService) GetAudioPublicUrl(filePath string) storage.SignedUrlResponse {
	return getPublicUrl(s, s.audioBucketId, filePath)
}

func (s *StorageService) GetImagePublicUrl(filePath string) storage.SignedUrlResponse {
	return getPublicUrl(s, s.imageBucketId, filePath)
}

func getPublicUrl(storageService *StorageService, bucketId string, filePath string) storage.SignedUrlResponse {
	options := storage.UrlOptions{
		Download: true,
	}
	return storageService.client.GetPublicUrl(bucketId, filePath, options)
}

func (s *StorageService) EnsureBucketsExists() {

	// This will fail incase bucket already existss after the first run
	// move these into the database insetad????
	_, err := s.client.GetBucket(s.audioBucketId)

	if err != nil {
		_, err = s.client.CreateBucket(s.audioBucketId, storage.BucketOptions{
			Public: true,
			AllowedMimeTypes: []string{
				"audio/ogg",
			},
		})

		if err != nil {
			ErrorLog("Failed to create audio bucket", "EnsureBucketsExists", err.Error())
		}
	}

	_, err = s.client.GetBucket(s.imageBucketId)

	if err != nil {
		_, err = s.client.CreateBucket(s.imageBucketId, storage.BucketOptions{
			Public: true,
			AllowedMimeTypes: []string{
				"image/jpeg",
			},
		})

		if err != nil {
			ErrorLog("Failed to create audio bucket", "EnsureBucketsExists", err.Error())
		}
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
	response, err := s.client.UploadFile(s.audioBucketId, fileName, file, *options)

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
	response, err := s.client.UploadFile(s.imageBucketId, fileName, file, *options)

	if err != nil {
		return storage.FileUploadResponse{}, err
	}
	return response, nil
}
