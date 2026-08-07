-- ============================================================================
--  CUNGA STOCK — COMPLETE DATABASE SCHEMA
--  Everything the app needs, in one file.
--
--  USE THIS WHEN DUPLICATING THE PROJECT:
--    1. Create a new Supabase project.
--    2. SQL Editor -> paste this entire file -> Run.
--    3. Settings -> API -> "Reload schema cache".
--    4. Copy the Project URL + anon key into .env as
--         VITE_SUPABASE_URL / VITE_SUPABASE_PUBLISHABLE_KEY
--    5. Sign up the first user in the app, then promote them to admin:
--         UPDATE public.user_roles SET role = 'admin'
--          WHERE user_id = (SELECT id FROM auth.users WHERE email = 'you@example.com');
--
--  This file is IDEMPOTENT — running it twice is safe, and running it on an
--  existing database brings that database up to date without losing data.
-- ============================================================================


-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ 1. ENUMS                                                                 │
-- └──────────────────────────────────────────────────────────────────────────┘

DO $$ BEGIN
  CREATE TYPE public.app_role AS ENUM ('admin', 'storekeeper');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.stock_status AS ENUM ('in_stock', 'out_of_stock', 'low_stock');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;


-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ 2. SHARED HELPERS                                                        │
-- └──────────────────────────────────────────────────────────────────────────┘

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

CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role public.app_role)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
     WHERE user_id = _user_id AND role = _role
  )
$$;

CREATE OR REPLACE FUNCTION public.get_user_role(_user_id UUID)
RETURNS public.app_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.user_roles WHERE user_id = _user_id LIMIT 1
$$;


-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ 3. AUTH: profiles + roles                                                │
-- └──────────────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.profiles (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name  TEXT NOT NULL,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_roles (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role       public.app_role NOT NULL DEFAULT 'storekeeper',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);

-- Every new signup gets a profile and the default 'storekeeper' role.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (user_id, full_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data ->> 'full_name', NEW.email))
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'storekeeper')
  ON CONFLICT (user_id, role) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ 4. GENERAL STOCK                                                         │
-- └──────────────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,
  description TEXT,
  color       TEXT DEFAULT '#3B82F6',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.stock_items (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name               TEXT NOT NULL,
  category_id        UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  quantity           INTEGER NOT NULL DEFAULT 0,
  min_quantity       INTEGER NOT NULL DEFAULT 5,
  status             public.stock_status NOT NULL DEFAULT 'in_stock',
  person_responsible TEXT,
  student_name       TEXT,
  notes              TEXT,
  total_added        INTEGER NOT NULL DEFAULT 0,
  issued             INTEGER NOT NULL DEFAULT 0,
  created_by         UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Columns added after the original schema — kept here so an older database
-- upgrades cleanly when this file is re-run.
ALTER TABLE public.stock_items ADD COLUMN IF NOT EXISTS student_name TEXT;
ALTER TABLE public.stock_items ADD COLUMN IF NOT EXISTS total_added INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.stock_items ADD COLUMN IF NOT EXISTS issued      INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS public.stock_movements (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id           UUID NOT NULL REFERENCES public.stock_items(id) ON DELETE CASCADE,
  movement_type     TEXT NOT NULL CHECK (movement_type IN ('added', 'issued', 'returned', 'adjusted')),
  quantity          INTEGER NOT NULL,
  previous_quantity INTEGER NOT NULL,
  new_quantity      INTEGER NOT NULL,
  notes             TEXT,
  performed_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.activity_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action      TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id   UUID,
  details     JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_stock_movements_item_id ON public.stock_movements (item_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_created ON public.stock_movements (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created   ON public.activity_logs (created_at DESC);

-- Stock status follows the quantity automatically.
CREATE OR REPLACE FUNCTION public.update_stock_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.quantity = 0 THEN
    NEW.status = 'out_of_stock';
  ELSIF NEW.quantity <= NEW.min_quantity THEN
    NEW.status = 'low_stock';
  ELSE
    NEW.status = 'in_stock';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS update_stock_status_trigger ON public.stock_items;
CREATE TRIGGER update_stock_status_trigger
  BEFORE INSERT OR UPDATE OF quantity ON public.stock_items
  FOR EACH ROW EXECUTE FUNCTION public.update_stock_status();

DROP TRIGGER IF EXISTS update_stock_items_updated_at ON public.stock_items;
CREATE TRIGGER update_stock_items_updated_at
  BEFORE UPDATE ON public.stock_items
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ 5. UNIFORMS                                                              │
-- │                                                                          │
-- │ uniform_issuances is the SINGLE SOURCE OF TRUTH for stock movement.      │
-- │ uniform_items.issued_quantity / remaining_quantity are always            │
-- │ RECALCULATED from it — never incremented — so they can never drift:      │
-- │                                                                          │
-- │   issued_quantity    = SUM(uniform_issuances.quantity_taken)             │
-- │   remaining_quantity = total_quantity - issued_quantity                  │
-- │                                                                          │
-- │ The app must NEVER write remaining_quantity or issued_quantity itself.   │
-- │ It only ever writes total_quantity (add item / restock) and rows in      │
-- │ uniform_issuances (issue / edit / delete).                               │
-- └──────────────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.uniform_categories (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.uniform_items (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name               TEXT NOT NULL,
  category           TEXT NOT NULL DEFAULT 'Uncategorized',
  total_quantity     INTEGER NOT NULL DEFAULT 0,  -- everything ever added
  issued_quantity    INTEGER NOT NULL DEFAULT 0,  -- derived, do not write
  remaining_quantity INTEGER NOT NULL DEFAULT 0,  -- derived, do not write
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.uniform_items
  ADD COLUMN IF NOT EXISTS issued_quantity INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS public.uniform_issuances (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uniform_id     UUID NOT NULL REFERENCES public.uniform_items(id) ON DELETE CASCADE,
  student_name   TEXT NOT NULL,
  quantity_taken INTEGER NOT NULL DEFAULT 1,
  issue_date     DATE NOT NULL DEFAULT CURRENT_DATE,
  sweater_number TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.uniform_issuances
  ADD COLUMN IF NOT EXISTS sweater_number TEXT;

-- A sweater number can only be assigned to one student (NULLs may repeat).
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'unique_sweater_number'
       AND conrelid = 'public.uniform_issuances'::regclass
  ) THEN
    ALTER TABLE public.uniform_issuances
      ADD CONSTRAINT unique_sweater_number UNIQUE (sweater_number);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_uniform_issuances_uniform_id
  ON public.uniform_issuances (uniform_id);
CREATE INDEX IF NOT EXISTS idx_uniform_issuances_created
  ON public.uniform_issuances (created_at DESC);


-- ── 5a. Recalculation routine ───────────────────────────────────────────────

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
     AND (issued_quantity    IS DISTINCT FROM v_issued
       OR remaining_quantity IS DISTINCT FROM GREATEST(total_quantity - v_issued, 0));
END;
$$;

COMMENT ON FUNCTION public.uniform_recalc_item(UUID) IS
  'Recomputes uniform_items.issued_quantity / remaining_quantity from uniform_issuances. Idempotent.';


-- ── 5b. Guard: an issuance can never exceed the stock that exists ──────────

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

  -- Row lock: two storekeepers issuing at the same instant can't both pass.
  SELECT total_quantity, name
    INTO v_total, v_name
    FROM public.uniform_items
   WHERE id = NEW.uniform_id
     FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'That uniform item no longer exists';
  END IF;

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

DROP TRIGGER IF EXISTS uniform_issuance_guard_trg ON public.uniform_issuances;
CREATE TRIGGER uniform_issuance_guard_trg
  BEFORE INSERT OR UPDATE ON public.uniform_issuances
  FOR EACH ROW EXECUTE FUNCTION public.uniform_issuance_guard();


-- ── 5c. Sync: recalc after any issuance insert / update / delete ──────────

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

  IF TG_OP = 'UPDATE' AND OLD.uniform_id IS DISTINCT FROM NEW.uniform_id THEN
    PERFORM public.uniform_recalc_item(OLD.uniform_id);
  END IF;

  PERFORM public.uniform_recalc_item(NEW.uniform_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS uniform_issuance_sync_trg ON public.uniform_issuances;
CREATE TRIGGER uniform_issuance_sync_trg
  AFTER INSERT OR UPDATE OR DELETE ON public.uniform_issuances
  FOR EACH ROW EXECUTE FUNCTION public.uniform_issuance_sync();


-- ── 5d. Item writes: derive issued/remaining from total_quantity ──────────
-- Only rewrites NEW, so it cannot recurse into uniform_recalc_item.

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

DROP TRIGGER IF EXISTS uniform_item_recalc_trg ON public.uniform_items;
CREATE TRIGGER uniform_item_recalc_trg
  BEFORE INSERT OR UPDATE OF total_quantity ON public.uniform_items
  FOR EACH ROW EXECUTE FUNCTION public.uniform_item_recalc();

DROP TRIGGER IF EXISTS update_uniform_items_updated_at ON public.uniform_items;
CREATE TRIGGER update_uniform_items_updated_at
  BEFORE UPDATE ON public.uniform_items
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ 6. TEMPORARY STOCK (teacher lending)                                     │
-- └──────────────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.temp_stock_items (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name               TEXT NOT NULL,
  description        TEXT,
  total_quantity     INTEGER NOT NULL DEFAULT 1,
  available_quantity INTEGER NOT NULL DEFAULT 1,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.temp_stock_loans (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id              UUID NOT NULL REFERENCES public.temp_stock_items(id) ON DELETE CASCADE,
  teacher_name         TEXT NOT NULL,
  department           TEXT,
  quantity             INTEGER NOT NULL DEFAULT 1,
  borrowed_date        DATE NOT NULL DEFAULT CURRENT_DATE,
  expected_return_date DATE,
  actual_return_date   DATE,
  status               TEXT NOT NULL DEFAULT 'borrowed',
  notes                TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_temp_stock_loans_item_id ON public.temp_stock_loans (item_id);

DROP TRIGGER IF EXISTS update_temp_stock_items_updated_at ON public.temp_stock_items;
CREATE TRIGGER update_temp_stock_items_updated_at
  BEFORE UPDATE ON public.temp_stock_items
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_temp_stock_loans_updated_at ON public.temp_stock_loans;
CREATE TRIGGER update_temp_stock_loans_updated_at
  BEFORE UPDATE ON public.temp_stock_loans
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ 7. ROW LEVEL SECURITY                                                    │
-- └──────────────────────────────────────────────────────────────────────────┘

ALTER TABLE public.profiles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_items        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.uniform_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.uniform_items      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.uniform_issuances  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.temp_stock_items   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.temp_stock_loans   ENABLE ROW LEVEL SECURITY;

-- profiles
DROP POLICY IF EXISTS "Users can view all profiles"  ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can view all profiles"  ON public.profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

-- user_roles (only admins may change roles)
DROP POLICY IF EXISTS "Authenticated users can view roles" ON public.user_roles;
DROP POLICY IF EXISTS "Admins can insert roles"            ON public.user_roles;
DROP POLICY IF EXISTS "Admins can update roles"            ON public.user_roles;
DROP POLICY IF EXISTS "Admins can delete roles"            ON public.user_roles;
CREATE POLICY "Authenticated users can view roles" ON public.user_roles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can insert roles" ON public.user_roles FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins can update roles" ON public.user_roles FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins can delete roles" ON public.user_roles FOR DELETE TO authenticated USING (public.has_role(auth.uid(), 'admin'));

-- categories / stock
DROP POLICY IF EXISTS "Authenticated users can view categories"   ON public.categories;
DROP POLICY IF EXISTS "Authenticated users can manage categories" ON public.categories;
CREATE POLICY "Authenticated users can view categories"   ON public.categories FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage categories" ON public.categories FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated users can view stock"   ON public.stock_items;
DROP POLICY IF EXISTS "Authenticated users can manage stock" ON public.stock_items;
CREATE POLICY "Authenticated users can view stock"   ON public.stock_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage stock" ON public.stock_items FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated users can view movements"   ON public.stock_movements;
DROP POLICY IF EXISTS "Authenticated users can insert movements" ON public.stock_movements;
CREATE POLICY "Authenticated users can view movements"   ON public.stock_movements FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert movements" ON public.stock_movements FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated users can view logs"   ON public.activity_logs;
DROP POLICY IF EXISTS "Authenticated users can insert logs" ON public.activity_logs;
CREATE POLICY "Authenticated users can view logs"   ON public.activity_logs FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert logs" ON public.activity_logs FOR INSERT TO authenticated WITH CHECK (true);

-- uniforms + temporary stock
DROP POLICY IF EXISTS "auth_uniform_categories" ON public.uniform_categories;
DROP POLICY IF EXISTS "auth_uniform_items"      ON public.uniform_items;
DROP POLICY IF EXISTS "auth_uniform_issuances"  ON public.uniform_issuances;
DROP POLICY IF EXISTS "auth_temp_stock_items"   ON public.temp_stock_items;
DROP POLICY IF EXISTS "auth_temp_stock_loans"   ON public.temp_stock_loans;
CREATE POLICY "auth_uniform_categories" ON public.uniform_categories FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "auth_uniform_items"      ON public.uniform_items      FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "auth_uniform_issuances"  ON public.uniform_issuances  FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "auth_temp_stock_items"   ON public.temp_stock_items   FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "auth_temp_stock_loans"   ON public.temp_stock_loans   FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ 8. REALTIME                                                              │
-- └──────────────────────────────────────────────────────────────────────────┘

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['stock_items', 'stock_movements', 'activity_logs',
                           'uniform_items', 'uniform_issuances'] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;


-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ 9. SEED DATA                                                             │
-- └──────────────────────────────────────────────────────────────────────────┘

INSERT INTO public.categories (name, description, color) VALUES
  ('Electronics', 'Computers, projectors, and electronic equipment', '#3B82F6'),
  ('Furniture',   'Desks, chairs, and office furniture',             '#10B981'),
  ('Stationery',  'Pens, papers, and office supplies',               '#F59E0B'),
  ('Sports',      'Sports equipment and gear',                       '#EF4444'),
  ('Laboratory',  'Lab equipment and chemicals',                     '#8B5CF6'),
  ('Cleaning',    'Cleaning supplies and equipment',                 '#06B6D4'),
  ('Books',       'Textbooks and library materials',                 '#EC4899'),
  ('Medical',     'First aid and medical supplies',                  '#F97316')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.uniform_categories (name) VALUES
  ('Shirts'), ('Trousers'), ('Skirts'), ('Sweaters'), ('Sports Wear'), ('Shoes')
ON CONFLICT (name) DO NOTHING;


-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ 10. REPAIR — bring any existing uniform rows in line                     │
-- └──────────────────────────────────────────────────────────────────────────┘

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


-- ============================================================================
--  DONE. Reload the schema cache: Settings -> API -> "Reload schema cache".
--
--  Health check — every row should say OK:
--    SELECT name, total_quantity AS total, issued_quantity AS issued,
--           remaining_quantity AS remaining,
--           CASE WHEN remaining_quantity = total_quantity - issued_quantity
--                THEN 'OK' ELSE 'MISMATCH' END AS status
--      FROM public.uniform_items ORDER BY name;
-- ============================================================================
