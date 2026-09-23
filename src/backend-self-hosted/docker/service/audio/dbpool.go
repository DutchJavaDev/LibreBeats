package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"sync"

	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	sharedPool *pgxpool.Pool
	poolMu     sync.Mutex
)

// InitDBPool creates the shared Postgres pool. Safe to call more than once.
func InitDBPool(ctx context.Context) error {
	poolMu.Lock()
	defer poolMu.Unlock()

	if sharedPool != nil {
		return nil
	}

	connectionString := os.Getenv("POSTGRES_BACKEND_URL")
	if connectionString == "" {
		return errors.New("POSTGRES_BACKEND_URL environment variable is not set")
	}

	pool, err := pgxpool.New(ctx, connectionString)
	if err != nil {
		return fmt.Errorf("create db pool: %w", err)
	}

	sharedPool = pool
	return nil
}

// GetDBPool returns the shared pool; nil if InitDBPool has not succeeded.
func GetDBPool() *pgxpool.Pool {
	poolMu.Lock()
	defer poolMu.Unlock()
	return sharedPool
}

// CloseDBPool closes the shared pool.
func CloseDBPool() {
	poolMu.Lock()
	defer poolMu.Unlock()
	if sharedPool != nil {
		sharedPool.Close()
		sharedPool = nil
	}
}

func requireDBPool() (*pgxpool.Pool, error) {
	pool := GetDBPool()
	if pool == nil {
		return nil, errors.New("database pool not initialized; call InitDBPool first")
	}
	return pool, nil
}
