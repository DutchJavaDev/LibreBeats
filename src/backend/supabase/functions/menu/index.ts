// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "jsr:@supabase/server@^1";

// This endpoint uses 'user' access, credentials is required.
export default {
  fetch: withSupabase({ auth: "user" }, async (_req, { supabase }) => {
      try {
    // ONE query: fetch all beatmixes with their beats (including duration)
    const { data, error } = await supabase
      .schema('librebeats')
      .from('beatmix')
      .select(`
        id,
        title,
        thumbnailurl,
        beatmixbeat (
          beat:beat (
            id,
            title,
            artist,
            thumbnailurl,
            streamingurl,
            rawbeat:rawbeat!beat_rawbeatid_fkey (duration)
          )
        )
      `)

    if (error) throw error

    // Transform to the expected shape (same as Dart code's result)
    const result = data.map((beatmix) => ({
      id: beatmix.id,
      title: beatmix.title,
      thumbnailurl: beatmix.thumbnailurl,
      // Map the junction array to a clean list of beats
      beats: beatmix.beatmixbeat.map((junction) => {
        const beat = junction.beat
        return {
          id: beat.id,
          title: beat.title,
          artist: beat.artist,
          thumbnailurl: beat.thumbnailurl,
          streamingurl: beat.streamingurl,
          duration: beat.rawbeat?.duration ?? null, // handle missing rawbeat
        }
      }),
      // Optional: add count if your frontend expects it
      count: beatmix.beatmixbeat.length,
    }))

    return new Response(JSON.stringify({ data: result }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error(error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
  }),
};