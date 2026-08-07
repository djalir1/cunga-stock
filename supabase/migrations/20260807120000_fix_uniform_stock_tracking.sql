-- ============================================================================
-- Migration: Fix uniform stock tracking (Remaining / Issued)
--
-- PROBLEM
--   `uniform_items.remaining_quantity` was a hand-maintained counter. Depending
--   on how many stock triggers ended up on `uniform_issuances`, issuing 5 of 30
--   could subtract 0, 5 or 10 — so "Remaining" drifted away from reality and
--   there was no real "Issued" number at all (the UI faked it with
--   total - remaining, which inherits the same drift).
--
-- FIX
--   `uniform_issuances` becomes the single source of truth. Both
--   `issued_quantity` and `remaining_quantity` are RECALCULATED from
--   SUM(quantity_taken) on every insert / update / delete instead of being
--   incremented. Recalculation is idempotent: even if a trigger fired twice the
--   numbers would still land on the correct value.
--
--   issued_quantity    = SUM(uniform_issuances.quantity_taken)
--   remaining_quantity = total_quantity - issued_quantity
--
-- HOW TO RUN
--   Supabase Dashboard -> SQL Editor -> paste this whole file -> Run.
--   Then: Settings -> API -> "Reload schema cache".
--   Safe to run more than once.
-- ============================================================================

BEGIN;

-- ── 1. Make sure the tables/columns this migration depends on exist ──────────

CREATE TABLE IF NOT EXISTS public.uniform_items (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name               TEXT NOT NULL,
  category           TEXT NOT NULL DEFAULT 'Uncategorized',
  total_quantity     INTEGER NOT NULL DEFAULT 0,
  remaining_quantity INTEGER NOT NULL DEFAULT 0,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.uniform_issuances (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uniform_id     UUID NOT NULL REFERENCES public.uniform_items(id) ON DELETE CASCADE,
  student_name   TEXT NOT NULL,
  quantity_taken INTEGER NOT NULL DEFAULT 1,
  issue_date     DATE NOT NULL DEFAULT CURRENT_DATE,
  sweater_number TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- The new column that finally stores a REAL issued count.
ALTER TABLE public.uniform_items
  ADD COLUMN IF NOT EXISTS issued_quantity INTEGER NOT NULL DEFAULT 0;

-- Every recalculation sums issuances per item — index it.
CREATE INDEX IF NOT EXISTS idx_uniform_issuances_uniform_id
  ON public.uniform_issuances (uniform_id);


-- ── 2. Wipe ALL pre-existing stock triggers (this is what caused the drift) ──
-- We don't know what the live database accumulated over time, so we remove
-- everything on these two tables and re-create exactly one correct set below.

DO $$
DECLARE t record;
BEGIN
  FOR t IN
    SELECT tgname
      FROM pg_trigger
     WHERE tgrelid = 'public.uniform_issuances'::regclass
       AND NOT tgisinternal
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.uniform_issuances', t.tgname);
  END LOOP;
END $$;

DO $$
DECLARE t record;
BEGIN
  FOR t IN
    SELECT tgname
      FROM pg_trigger
     WHERE tgrelid = 'public.uniform_items'::regclass
       AND NOT tgisinternal
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.uniform_items', t.tgname);
  END LOOP;
END $$;


-- ── 3. The recalculation routine ────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.uniform_recalc_item(p_uniform_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_issued INTEGER;
BEGIN
  IF p_uniform_id IS NULL THEN
    RETURN;
  END IF;

  SELECT COALESCE(SUM(quantity_taken), 0)
    INTO v_issued
    FROM public.uniform_issuances
   WHERE uniform_id = p_uniform_id;

  UPDATE public.uniform_items
     SET issued_quantity    = v_issued,
         remaining_quantity = GREATEST(total_quantity - v_issued, 0),
         updated_at         = now()
   WHERE id = p_uniform_id
     -- skip a pointless write when the numbers are already correct
     AND (issued_quantity    IS DISTINCT FROM v_issued
       OR remaining_quantity IS DISTINCT FROM GREATEST(total_quantity - v_issued, 0));
END;
$$;

COMMENT ON FUNCTION public.uniform_recalc_item(UUID) IS
  'Recomputes uniform_items.issued_quantity / remaining_quantity from uniform_issuances. Idempotent.';


-- ── 4. Guard: never let an issuance exceed the stock that exists ────────────

CREATE OR REPLACE FUNCTION public.uniform_issuance_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total        INTEGER;
  v_name         TEXT;
  v_other_issued INTEGER;
BEGIN
  IF NEW.quantity_taken IS NULL OR NEW.quantity_taken < 1 THEN
    RAISE EXCEPTION 'Quantity issued must be at least 1';
  END IF;

  -- Lock the item row so two storekeepers issuing at the same moment
  -- can't both slip past the check.
  SELECT total_quantity, name
    INTO v_total, v_name
    FROM public.uniform_items
   WHERE id = NEW.uniform_id
     FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'That uniform item no longer exists';
  END IF;

  -- Everything already issued for this item, excluding the row being written.
  SELECT COALESCE(SUM(quantity_taken), 0)
    INTO v_other_issued
    FROM public.uniform_issuances
   WHERE uniform_id = NEW.uniform_id
     AND id <> NEW.id;

  IF v_other_issued + NEW.quantity_taken > v_total THEN
    RAISE EXCEPTION 'Not enough stock for "%": % available, % requested',
      v_name, v_total - v_other_issued, NEW.quantity_taken;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER uniform_issuance_guard_trg
  BEFORE INSERT OR UPDATE ON public.uniform_issuances
  FOR EACH ROW EXECUTE FUNCTION public.uniform_issuance_guard();


-- ── 5. Sync: recalc the item after any issuance changes ────────────────────

CREATE OR REPLACE FUNCTION public.uniform_issuance_sync()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.uniform_recalc_item(OLD.uniform_id);
    RETURN OLD;
  END IF;

  -- Record moved to a different uniform: fix the item it left, too.
  IF TG_OP = 'UPDATE' AND OLD.uniform_id IS DISTINCT FROM NEW.uniform_id THEN
    PERFORM public.uniform_recalc_item(OLD.uniform_id);
  END IF;

  PERFORM public.uniform_recalc_item(NEW.uniform_id);
  RETURN NEW;
END;
$$;

CREATE TRIGGER uniform_issuance_sync_trg
  AFTER INSERT OR UPDATE OR DELETE ON public.uniform_issuances
  FOR EACH ROW EXECUTE FUNCTION public.uniform_issuance_sync();


-- ── 6. Restock: keep the item's own numbers honest ─────────────────────────
-- Fires on INSERT and whenever total_quantity is written (restock / edit).
-- It only rewrites NEW, so it can never recurse into uniform_recalc_item.

CREATE OR REPLACE FUNCTION public.uniform_item_recalc()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_issued INTEGER;
BEGIN
  IF NEW.total_quantity < 0 THEN
    RAISE EXCEPTION 'Total stock cannot be negative';
  END IF;

  SELECT COALESCE(SUM(quantity_taken), 0)
    INTO v_issued
    FROM public.uniform_issuances
   WHERE uniform_id = NEW.id;

  IF v_issued > NEW.total_quantity THEN
    RAISE EXCEPTION 'Cannot set total stock to % — % have already been issued',
      NEW.total_quantity, v_issued;
  END IF;

  NEW.issued_quantity    := v_issued;
  NEW.remaining_quantity := NEW.total_quantity - v_issued;
  NEW.updated_at         := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER uniform_item_recalc_trg
  BEFORE INSERT OR UPDATE OF total_quantity ON public.uniform_items
  FOR EACH ROW EXECUTE FUNCTION public.uniform_item_recalc();

-- Plain edits (name / category) still bump updated_at.
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_uniform_items_updated_at
  BEFORE UPDATE ON public.uniform_items
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


-- ── 7. Repair every existing row ───────────────────────────────────────────
-- GREATEST(total, issued): if past drift left an item with more issued than
-- total, the total must really have been at least that high — raise it so the
-- data is consistent instead of showing a negative remainder.

UPDATE public.uniform_items i
   SET total_quantity     = GREATEST(i.total_quantity, s.issued),
       issued_quantity    = s.issued,
       remaining_quantity = GREATEST(i.total_quantity, s.issued) - s.issued,
       updated_at         = now()
  FROM (
    SELECT it.id,
           COALESCE((
             SELECT SUM(iss.quantity_taken)
               FROM public.uniform_issuances iss
              WHERE iss.uniform_id = it.id
           ), 0) AS issued
      FROM public.uniform_items it
  ) s
 WHERE i.id = s.id;

COMMIT;

-- ============================================================================
-- VERIFY (run separately after the migration; every row should read OK)
-- ============================================================================
--
-- SELECT name,
--        category,
--        total_quantity     AS total,
--        issued_quantity    AS issued,
--        remaining_quantity AS remaining,
--        CASE WHEN remaining_quantity = total_quantity - issued_quantity
--             THEN 'OK' ELSE 'MISMATCH' END AS check
--   FROM public.uniform_items
--  ORDER BY name;
--
-- -- Only these three triggers should exist on uniform_issuances/uniform_items:
-- --   uniform_issuance_guard_trg, uniform_issuance_sync_trg,
-- --   uniform_item_recalc_trg, update_uniform_items_updated_at
-- SELECT c.relname AS table_name, t.tgname AS trigger_name
--   FROM pg_trigger t
--   JOIN pg_class c ON c.oid = t.tgrelid
--  WHERE NOT t.tgisinternal
--    AND c.relname IN ('uniform_items', 'uniform_issuances')
--  ORDER BY 1, 2;
-- ============================================================================
