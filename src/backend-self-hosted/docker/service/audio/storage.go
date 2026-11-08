package main

import (
	"fmt"
	"os"
	"strings"

	storage "github.com/supabase-community/storage-go"
)

type IStorageService interface {
	EnsureBucketsExists()
	GetAudioPublicUrl(filename string) storage.SignedUrlResponse
	UploadAudioFile(filePath string, fileName string) (storage.FileUploadResponse, error)
	GetImagePublicUrl(filename string) storage.SignedUrlResponse
	UploadImageFile(filePath string, fileName string) (storage.FileUploadResponse, error)

	uploadFile(filePath string, fileName string, contentType string, bucketId string) (storage.FileUploadResponse, error)
	getPublicUrl(bucketId string, filePath string) storage.SignedUrlResponse
}

type StorageService struct {
	IStorageService
	client        *storage.Client
	audioBucketId string
	imageBucketId string
	publicBaseUrl string
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

	publicBaseUrl := os.Getenv("STORAGE_PUBLIC_URL")

	if publicBaseUrl == "" {
		panic("STORAGE_PUBLIC_URL environment variable is not set")
	}

	storageClient := storage.NewClient(storageUrl, storageKey, nil)

	return &StorageService{
		client:        storageClient,
		audioBucketId: audioBucketId,
		imageBucketId: imageBucketId,
		publicBaseUrl: strings.TrimRight(publicBaseUrl, "/"),
	}
}

func (s *StorageService) GetAudioPublicUrl(filePath string) storage.SignedUrlResponse {
	return s.getPublicUrl(s.audioBucketId, filePath)
}

func (s *StorageService) GetImagePublicUrl(filePath string) storage.SignedUrlResponse {
	return s.getPublicUrl(s.imageBucketId, filePath)
}

func (s *StorageService) getPublicUrl(bucketId string, filePath string) storage.SignedUrlResponse {
	// Public object URLs must point at the externally reachable host
	// (STORAGE_PUBLIC_URL), not the internal gateway (STORAGE_URL), otherwise
	// clients outside the Docker network cannot stream audio or load artwork.
	urlStr := fmt.Sprintf("%s/storage/v1/object/public/%s/%s?download=true", s.publicBaseUrl, bucketId, filePath)
	return storage.SignedUrlResponse{SignedURL: urlStr}
}

func (s *StorageService) EnsureBucketsExists() {

	// This will fail incase bucket already existss after the first run
	// move these into the database instead????
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

func (s *StorageService) uploadFile(filePath string, fileName string, contentType string, bucketId string) (storage.FileUploadResponse, error) {
	// Open the file you want to upload
	file, err := os.Open(filePath)
	if err != nil {
		return storage.FileUploadResponse{}, err
	}
	defer file.Close()

	// Upload the file to the specified bucket and path
	upsert := true
	options := &storage.FileOptions{
		ContentType: &contentType,
		Upsert:      &upsert,
	}
	response, err := s.client.UploadFile(bucketId, fileName, file, *options)

	if err != nil {
		return storage.FileUploadResponse{}, err
	}
	return response, nil
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
