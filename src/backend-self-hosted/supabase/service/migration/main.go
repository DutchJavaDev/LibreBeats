package main

import (
	"fmt"
	"os"
)

func main() {
	migration := NewMigrationInstance()

	if migration == nil {
		panic("Could not connect to database")
	}

	err := migration.Run()

	if err != nil {
		fmt.Println("Error applying migrations: " + err.Error())
		os.Exit(1)
	}

	fmt.Println("Migrations applied successfully")
}
