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
		fmt.Println("Error applying migrations: " + err.Error())
		return
	}

	fmt.Println("Migrations applied successfully")
}
