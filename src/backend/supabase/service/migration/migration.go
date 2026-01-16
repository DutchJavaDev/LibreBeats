package main

import (
	"context"
	"fmt"
	"os"
	"path"
	"strconv"
	"strings"

	"github.com/jackc/pgx/v5"
)

const _migrationFolderName = "scripts"

type IMaigration interface {
	Run() error
}

type Migration struct {
	_connection *pgx.Conn
	IMaigration
}

func NewMigrationInstance() IMaigration {
	conn, err := pgx.Connect(context.Background(), os.Getenv("POSTGRES_BACKEND_URL"))

	if err != nil {
		return nil
	}

	return &Migration{
		_connection: conn,
	}
}

func (m *Migration) Run() error {

	lastAppliedMigrationId := m._LastAppliedMigrationId()

	tx, err := m._connection.Begin(context.Background())

	if err != nil {
		return err
	}

	_dir, err := os.Getwd()

	if err != nil {
		return err
	}

	migrationFolderPath := path.Join(_dir, _migrationFolderName)

	dirs, err := os.ReadDir(migrationFolderPath)
	if err != nil {
		return err
	}

	for _, dirEntry := range dirs {

		if dirEntry.IsDir() {
			fmt.Println("Already applied skipping folder:", dirEntry.Name())
			continue
		}

		sqlScriptPath := path.Join(migrationFolderPath, dirEntry.Name())

		migrationFileId, err := strconv.Atoi(strings.Split(dirEntry.Name(), " ")[0])

		if err != nil {
			defer tx.Rollback(context.Background())
			return err
		}

		if migrationFileId <= lastAppliedMigrationId {
			continue
		}

		sqlScript, err := os.ReadFile(sqlScriptPath)

		if err != nil {
			return err
		}

		_, err = tx.Exec(context.Background(), string(sqlScript))

		if err != nil {
			defer tx.Rollback(context.Background())
			return err
		}

		_, err = tx.Exec(context.Background(), "INSERT INTO librebeats.migrations (id, file_name, content, run_on) VALUES ($1, $2, $3, NOW())", migrationFileId, dirEntry.Name(), string(sqlScript))

		if err != nil {
			defer tx.Rollback(context.Background())
			return err
		}

		fmt.Println("Applied migration:", dirEntry.Name())
	}

	err = tx.Commit(context.Background())

	if err != nil {
		return err
	}

	return nil
}

func (m *Migration) _LastAppliedMigrationId() int {

	var lastAppliedMigrationId int

	err := m._connection.QueryRow(context.Background(), "SELECT id FROM librebeats.migrations ORDER BY run_on DESC LIMIT 1").Scan(&lastAppliedMigrationId)

	if err != nil {
		return -1
	}

	return lastAppliedMigrationId
}
