package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestMigrationScriptsFolderNaming(t *testing.T) {
	t.Parallel()

	scriptsDir := filepath.Join("scripts")
	entries, err := os.ReadDir(scriptsDir)
	if err != nil {
		t.Skipf("scripts directory not available from test cwd: %v", err)
	}

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		id, err := parseMigrationFileID(entry.Name())
		if err != nil {
			t.Fatalf("script %q: %v", entry.Name(), err)
		}
		if id < 0 {
			t.Fatalf("script %q has negative id %d", entry.Name(), id)
		}
	}
}
