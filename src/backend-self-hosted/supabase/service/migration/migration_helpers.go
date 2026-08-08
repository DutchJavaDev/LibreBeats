package main

import (
	"fmt"
	"strconv"
	"strings"
)

// parseMigrationFileID reads the numeric prefix from filenames like "0 initial.sql".
func parseMigrationFileID(fileName string) (int, error) {
	parts := strings.Split(fileName, " ")
	if len(parts) == 0 || parts[0] == "" {
		return 0, fmt.Errorf("invalid migration file name: %q", fileName)
	}
	id, err := strconv.Atoi(parts[0])
	if err != nil {
		return 0, fmt.Errorf("invalid migration file id in %q: %w", fileName, err)
	}
	return id, nil
}

// isMigrationsTableMissingErr reports whether Postgres has no Librebeats.Migrations table yet.
func isMigrationsTableMissingErr(err error) bool {
	if err == nil {
		return false
	}
	return strings.Contains(err.Error(), `ERROR: relation "librebeats.migrations" does not exist (SQLSTATE 42P01)`)
}
