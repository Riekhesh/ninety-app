-- ═══════════════════════════════════════════════════════════════════════════
-- Ninety — migration 006: ranked full-text search over the food catalogue.
--
-- P1-F Path 1: "debounced query against the tsvector index; results feel
-- instant." The index and the `search_vector` column have been there since
-- migration 001; this is the query that uses them properly.
--
-- ─── Why a function rather than a filter from the client ───────────────────
--
-- Ranking. Without `ts_rank` the results come back in whatever order Postgres
-- finds them, which for a catalogue of a few hundred thousand rows means the
-- right answer is somewhere on the list rather than at the top. The weights
-- were set in 001 — name is 'A', brand is 'B', so someone searching "hummus"
-- gets hummus rather than every product made by a company with hummus in its
-- name — and that weighting only does anything if something orders by rank.
--
-- Putting it here also keeps `websearch_to_tsquery` server-side, which is the
-- parser that treats a bare "greek yogurt" as an AND of its words. A plain
-- tsquery on the same string matches either word and buries the right answer
-- under everything yoghurt-adjacent.
--
-- ─── Why it is SECURITY INVOKER ────────────────────────────────────────────
--
-- Deliberately not DEFINER. `foods` is the one table in the schema whose read
-- policy is not user-scoped — a catalogue only its creator can see is a
-- catalogue nobody benefits from — but custom rows still belong to whoever made
-- them, and the select policy is what says so. Running as the invoker means
-- this function cannot return a row the caller could not have selected
-- themselves, so search inherits RLS rather than stepping around it.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function search_foods(query text, max_results integer default 25)
returns setof foods
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select f.*
  from foods f
  -- `websearch_to_tsquery` never raises on user input. `to_tsquery` does — a
  -- stray `&` or an unbalanced quote is a syntax error, and a search box is
  -- exactly where those arrive.
  where f.search_vector @@ websearch_to_tsquery('english', query)
  order by
    ts_rank(f.search_vector, websearch_to_tsquery('english', query)) desc,
    -- A stable tiebreak, so paging and repeated queries do not reshuffle rows
    -- that rank identically.
    f.name
  limit least(greatest(coalesce(max_results, 25), 1), 100);
$$;

grant execute on function search_foods(text, integer) to authenticated;
