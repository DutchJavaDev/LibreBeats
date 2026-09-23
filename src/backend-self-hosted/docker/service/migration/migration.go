package main

import (
	"context"
	"fmt"
	"os"
	"path"

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

	lastAppliedMigrationId, err := m._LastAppliedMigrationId()

	if err != nil {
		return err
	}

	fmt.Println("Last applied migration id:", lastAppliedMigrationId)

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

	sortMigrationFiles(dirs)

	for _, dirEntry := range dirs {

		fmt.Println("Processing migration file:", dirEntry.Name())

		if dirEntry.IsDir() {
			fmt.Println("Skipping directory:", dirEntry.Name())
			continue
		}

		sqlScriptPath := path.Join(migrationFolderPath, dirEntry.Name())

		migrationFileId, err := parseMigrationFileID(dirEntry.Name())

		if err != nil {
			defer tx.Rollback(context.Background())
			return err
		}

		if migrationFileId <= lastAppliedMigrationId {
			fmt.Println("Skipping already applied migration:", dirEntry.Name())
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

		_, err = tx.Exec(context.Background(), "INSERT INTO Librebeats.Migrations (migrationFileId, fileName, content, runOn) VALUES ($1, $2, $3, NOW())", migrationFileId, dirEntry.Name(), string(sqlScript))

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

func (m *Migration) _LastAppliedMigrationId() (int, error) {
	var lastAppliedMigrationId int = -1

	err := m._connection.QueryRow(context.Background(), "SELECT COALESCE(MAX(MigrationFileId), -1) FROM Librebeats.Migrations").Scan(&lastAppliedMigrationId)

	if err != nil {
		if isMigrationsTableMissingErr(err) {
			fmt.Println("Migrations table does not exist, assuming no migrations have been applied yet.")
			return -1, nil
		}

		fmt.Println("Error fetching last applied migrationId:", err.Error())
		return -1, err
	}

	return lastAppliedMigrationId, nil
}
