package main

import (
	"errors"
	"testing"
)

func TestParseMigrationFileID(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		file    string
		want    int
		wantErr bool
	}{
		{name: "initial migration", file: "0 initial.sql", want: 0},
		{name: "numbered migration", file: "12 add beats.sql", want: 12},
		{name: "invalid prefix", file: "abc initial.sql", wantErr: true},
		{name: "empty name", file: "", wantErr: true},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			got, err := parseMigrationFileID(tt.file)
			if tt.wantErr {
				if err == nil {
					t.Fatalf("parseMigrationFileID(%q) expected error", tt.file)
				}
				return
			}
			if err != nil {
				t.Fatalf("parseMigrationFileID(%q): %v", tt.file, err)
			}
			if got != tt.want {
				t.Fatalf("parseMigrationFileID(%q) = %d, want %d", tt.file, got, tt.want)
			}
		})
	}
}

func TestIsMigrationsTableMissingErr(t *testing.T) {
	t.Parallel()

	missing := errors.New(`ERROR: relation "librebeats.migrations" does not exist (SQLSTATE 42P01)`)
	other := errors.New("connection refused")

	if !isMigrationsTableMissingErr(missing) {
		t.Fatal("expected missing-table error to match")
	}
	if isMigrationsTableMissingErr(other) {
		t.Fatal("expected unrelated error not to match")
	}
	if isMigrationsTableMissingErr(nil) {
		t.Fatal("expected nil error not to match")
	}
}
