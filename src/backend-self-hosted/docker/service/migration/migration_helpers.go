package main

import (
	"fmt"
	"os"
	"sort"
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

// sortMigrationFiles sorts the scripts by their id, os.ReadDir gives them back in name order
// so "10 something.sql" would run before "2 something.sql"
func sortMigrationFiles(dirs []os.DirEntry) {
	sort.Slice(dirs, func(i, j int) bool {
		idA, _ := parseMigrationFileID(dirs[i].Name())
		idB, _ := parseMigrationFileID(dirs[j].Name())
		return idA < idB
	})
}

// isMigrationsTableMissingErr reports whether Postgres has no Librebeats.Migrations table yet.
func isMigrationsTableMissingErr(err error) bool {
	if err == nil {
		return false
	}
	return strings.Contains(err.Error(), `ERROR: relation "librebeats.migrations" does not exist (SQLSTATE 42P01)`)
}
