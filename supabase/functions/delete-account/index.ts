import { withSupabase } from 'npm:@supabase/server@1.8.0'

// Deletes the caller's own account — and only theirs: the id comes from the
// verified session JWT, never from the request body.
//
// Whatever a user owns must reference auth.users with `on delete cascade`, so
// this stays a single call as tables arrive.
export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method !== 'POST') return new Response(null, { status: 405 })

    const { error } = await ctx.supabaseAdmin.auth.admin.deleteUser(
      ctx.userClaims!.id,
    )
    if (error) {
      console.error('delete-account failed', error)
      return Response.json({ error: 'delete_failed' }, { status: 500 })
    }
    return new Response(null, { status: 204 })
  }),
}
