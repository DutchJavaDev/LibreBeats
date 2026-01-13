package main

import (
	"fmt"
	"os"

	"github.com/supabase-community/supabase-go"
)

func main() {
	options := &supabase.ClientOptions{
		Schema: "pgmq_public",
	}

	client, err := supabase.NewClient(os.Getenv("SUPABASE_URL"), os.Getenv("SUPABASE_SERVICE_KEY"), options)

	if err != nil {
		fmt.Println("Error creating Supabase client:", err)
		return
	}

	type PopResponse struct {
		QueueName string `json:"queue_name"`
	}

	var rps = &PopResponse{}
	rps.QueueName = "test"

	data := client.Rpc("pop", "", rps)

	fmt.Println("Data:", data)

	// Example query to fetch data from a table

	// data, count, err := client.From("librebeats_settings").Select("", "exact", false).Execute()

	// if err != nil {
	// 	fmt.Println("Error fetching data:", err.Error())
	// 	return
	// }

	// fmt.Println("Data:", string(data))
	// fmt.Println("Count:", count)
}
