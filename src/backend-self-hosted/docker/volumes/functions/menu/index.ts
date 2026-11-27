// Setup type definitions for built-in Supabase Runtime APIs
import "@supabase/functions-js/edge-runtime.d.ts"
import { withSupabase } from "@supabase/server"

// The catalog endpoint the app calls: returns every beatmix with its beats
// embedded (id, title, artist, thumbnail, streaming url, duration) in one
// query. This endpoint uses 'user' access, a signed-in JWT is required.
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

      // Transform to the expected shape (same as the Dart app's result)
      const result = data.map((beatmix) => ({
        id: beatmix.id,
        title: beatmix.title,
        thumbnailurl: beatmix.thumbnailurl,
        beats: beatmix.beatmixbeat.map((junction) => {
          const beat = junction.beat
          return {
            id: beat.id,
            title: beat.title,
            artist: beat.artist,
            thumbnailurl: beat.thumbnailurl,
            streamingurl: beat.streamingurl,
            duration: beat.rawbeat?.duration ?? null,
          }
        }),
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
}
