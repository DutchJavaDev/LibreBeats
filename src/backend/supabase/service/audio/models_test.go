package main

import (
	"encoding/json"
	"testing"
)

func TestAudioPipeQueueMessageJSON(t *testing.T) {
	t.Parallel()

	raw := `{"msg_id":42,"message":{"url":"https://www.youtube.com/watch?v=test"}}`
	var msg AudioPipeQueueMessage
	if err := json.Unmarshal([]byte(raw), &msg); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if msg.Id != 42 {
		t.Fatalf("Id = %d, want 42", msg.Id)
	}

	url, err := parseAudioPipeURL(msg.Message)
	if err != nil {
		t.Fatalf("parseAudioPipeURL: %v", err)
	}
	if url != "https://www.youtube.com/watch?v=test" {
		t.Fatalf("url = %q", url)
	}
}

func TestProgressStateValues(t *testing.T) {
	t.Parallel()

	if Failed != 0 {
		t.Fatalf("Failed = %d, want 0", Failed)
	}
	if Created != 1 {
		t.Fatalf("Created = %d, want 1", Created)
	}
	if Downloading != 2 {
		t.Fatalf("Downloading = %d, want 2", Downloading)
	}
	if Completed != 3 {
		t.Fatalf("Completed = %d, want 3", Completed)
	}
}

func TestProgressStateString(t *testing.T) {
	t.Parallel()

	tests := []struct {
		state ProgressState
		want  string
	}{
		{Failed, "failed"},
		{Created, "created"},
		{Downloading, "donwloading"},
		{Completed, "completed"},
	}
	for _, tt := range tests {
		if got := tt.state.String(); got != tt.want {
			t.Fatalf("%v.String() = %q, want %q", tt.state, got, tt.want)
		}
	}
}
