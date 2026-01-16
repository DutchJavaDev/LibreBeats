package main

import (
	"fmt"
)

func main() {
	migration := NewMigrationInstance()

	if migration == nil {
		panic("Could not connect to database")
	}

	err := migration.Run()

	if err != nil {
		panic(err)
	}

	fmt.Println("Migrations applied successfully")
}
