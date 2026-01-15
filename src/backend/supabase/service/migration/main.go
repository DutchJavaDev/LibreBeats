package main

import (
	"context"
	"log"
	"os"
	"time"

	"github.com/jackc/pgx/v5"
)

// urlExample := "postgres://username:password@localhost:5432/database_name"
func main() {
	// options := &supabase.ClientOptions{
	// 	Schema: "pgmq_public",
	// }

	// client, err := supabase.NewClient(os.Getenv("SUPABASE_URL"), os.Getenv("SUPABASE_SERVICE_KEY"), options)

	// if err != nil {
	// 	fmt.Println("Error creating Supabase client:", err)
	// 	return
	// }

	conn, err := pgx.Connect(context.Background(), os.Getenv("POSTGRES_BACKEND_URL"))
	if err != nil {
		log.Fatalf("Failed to connect to the database: %v", err)
	}

	tx, err := conn.Begin(context.Background())
	if err != nil {
		log.Fatalf("Failed to begin transaction: %v", err)
	}

	sqlScript, err := os.ReadFile("scripts/script.sql")
	if err != nil {
		log.Fatalf("Failed to read SQL script: %v", err)
	}

	_, err = tx.Exec(context.Background(), string(sqlScript))

	if err != nil {
		defer tx.Rollback(context.Background())
		log.Fatalf("Failed to execute SQL script: %v", err)
	}

	err = tx.Commit(context.Background())
	if err != nil {
		log.Fatalf("Failed to commit transaction: %v", err)
	}

	rows, err := conn.Query(context.Background(), "SELECT * FROM Song")
	if err != nil {
		log.Fatalf("Failed to query songs: %v", err)
	}
	defer rows.Close()

	type Song struct {
		Id            int
		Name          string
		SourceId      string
		Path          string
		ThumbnailPath string
		Duration      int
		CreatedAt     time.Time
		UpdatedAt     time.Time
	}

	for rows.Next() {
		var song Song
		if err := rows.Scan(&song.Id, &song.Name, &song.SourceId, &song.Path, &song.ThumbnailPath, &song.Duration, &song.CreatedAt, &song.UpdatedAt); err != nil {
			log.Fatalf("Failed to scan song: %v", err)
		}
		log.Printf("Song: %+v\n", song)
	}

	log.Println("Successfully connected to the database")

	// type PopResponse struct {
	// 	QueueName string `json:"queue_name"`
	// }

	// var rps = &PopResponse{}
	// rps.QueueName = "test"

	// data := client.Rpc("pop", "", rps)

	// fmt.Println("Data:", data)

	//Example query to fetch data from a table

	// data, count, err := client.From("librebeats_settings").Select("", "exact", false).Execute()

	// if err != nil {
	// 	fmt.Println("Error fetching data:", err.Error())
	// 	return
	// }

	// fmt.Println("Data:", string(data))
	// fmt.Println("Count:", count)
}
