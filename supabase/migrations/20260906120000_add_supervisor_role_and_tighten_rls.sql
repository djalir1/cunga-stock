-- Add a third role, 'supervisor', and gate write access on tables to
-- admin + storekeeper only. Supervisors keep SELECT access everywhere.
--
-- Before this change:
--   - app_role enum had only 'admin' and 'storekeeper'
--   - handle_new_user() assigned every fresh signup 'storekeeper' by default
--   - Table RLS granted ALL to any authenticated user
--   - The frontend gated writes on role === 'storekeeper', so admins saw the
--     app in "Supervisor Mode (View Only)" even though they were admins.

-- 1) Extend the role enum. Must not be inside a txn on older Postgres; the
--    Supabase migration runner handles that for us.
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'supervisor';

-- 2) Fresh signups default to supervisor. An admin promotes them from the app.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.profiles (user_id, full_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data ->> 'full_name', NEW.email));

  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'supervisor');

  RETURN NEW;
END;
$function$;

-- 3) Helper predicate: "can this user edit stock?" — admin or storekeeper.
CREATE OR REPLACE FUNCTION public.can_edit_stock(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id
      AND role IN ('admin'::app_role, 'storekeeper'::app_role)
  )
$function$;

-- 4) Replace open "authenticated can do anything" write policies with role-gated
--    ones. SELECT stays open to authenticated so supervisors can read.

-- categories
DROP POLICY IF EXISTS "Authenticated users can manage categories" ON public.categories;
CREATE POLICY "Editors can insert categories"
  ON public.categories FOR INSERT TO authenticated
  WITH CHECK (public.can_edit_stock(auth.uid()));
CREATE POLICY "Editors can update categories"
  ON public.categories FOR UPDATE TO authenticated
  USING (public.can_edit_stock(auth.uid()))
  WITH CHECK (public.can_edit_stock(auth.uid()));
CREATE POLICY "Editors can delete categories"
  ON public.categories FOR DELETE TO authenticated
  USING (public.can_edit_stock(auth.uid()));

-- stock_items
DROP POLICY IF EXISTS "Authenticated users can manage stock" ON public.stock_items;
CREATE POLICY "Editors can insert stock"
  ON public.stock_items FOR INSERT TO authenticated
  WITH CHECK (public.can_edit_stock(auth.uid()));
CREATE POLICY "Editors can update stock"
  ON public.stock_items FOR UPDATE TO authenticated
  USING (public.can_edit_stock(auth.uid()))
  WITH CHECK (public.can_edit_stock(auth.uid()));
CREATE POLICY "Editors can delete stock"
  ON public.stock_items FOR DELETE TO authenticated
  USING (public.can_edit_stock(auth.uid()));

-- stock_movements
DROP POLICY IF EXISTS "Authenticated users can insert movements" ON public.stock_movements;
CREATE POLICY "Editors can insert movements"
  ON public.stock_movements FOR INSERT TO authenticated
  WITH CHECK (public.can_edit_stock(auth.uid()));

-- temp_stock_items
DROP POLICY IF EXISTS "auth_temp_stock_items" ON public.temp_stock_items;
CREATE POLICY "temp_stock_items_select"
  ON public.temp_stock_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "temp_stock_items_insert"
  ON public.temp_stock_items FOR INSERT TO authenticated
  WITH CHECK (public.can_edit_stock(auth.uid()));
CREATE POLICY "temp_stock_items_update"
  ON public.temp_stock_items FOR UPDATE TO authenticated
  USING (public.can_edit_stock(auth.uid()))
  WITH CHECK (public.can_edit_stock(auth.uid()));
CREATE POLICY "temp_stock_items_delete"
  ON public.temp_stock_items FOR DELETE TO authenticated
  USING (public.can_edit_stock(auth.uid()));

-- temp_stock_loans
DROP POLICY IF EXISTS "auth_temp_stock_loans" ON public.temp_stock_loans;
CREATE POLICY "temp_stock_loans_select"
  ON public.temp_stock_loans FOR SELECT TO authenticated USING (true);
CREATE POLICY "temp_stock_loans_insert"
  ON public.temp_stock_loans FOR INSERT TO authenticated
  WITH CHECK (public.can_edit_stock(auth.uid()));
CREATE POLICY "temp_stock_loans_update"
  ON public.temp_stock_loans FOR UPDATE TO authenticated
  USING (public.can_edit_stock(auth.uid()))
  WITH CHECK (public.can_edit_stock(auth.uid()));
CREATE POLICY "temp_stock_loans_delete"
  ON public.temp_stock_loans FOR DELETE TO authenticated
  USING (public.can_edit_stock(auth.uid()));

-- uniform_categories
DROP POLICY IF EXISTS "auth_uniform_categories" ON public.uniform_categories;
CREATE POLICY "uniform_categories_select"
  ON public.uniform_categories FOR SELECT TO authenticated USING (true);
CREATE POLICY "uniform_categories_insert"
  ON public.uniform_categories FOR INSERT TO authenticated
  WITH CHECK (public.can_edit_stock(auth.uid()));
CREATE POLICY "uniform_categories_update"
  ON public.uniform_categories FOR UPDATE TO authenticated
  USING (public.can_edit_stock(auth.uid()))
  WITH CHECK (public.can_edit_stock(auth.uid()));
CREATE POLICY "uniform_categories_delete"
  ON public.uniform_categories FOR DELETE TO authenticated
  USING (public.can_edit_stock(auth.uid()));

-- uniform_items
DROP POLICY IF EXISTS "auth_uniform_items" ON public.uniform_items;
CREATE POLICY "uniform_items_select"
  ON public.uniform_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "uniform_items_insert"
  ON public.uniform_items FOR INSERT TO authenticated
  WITH CHECK (public.can_edit_stock(auth.uid()));
CREATE POLICY "uniform_items_update"
  ON public.uniform_items FOR UPDATE TO authenticated
  USING (public.can_edit_stock(auth.uid()))
  WITH CHECK (public.can_edit_stock(auth.uid()));
CREATE POLICY "uniform_items_delete"
  ON public.uniform_items FOR DELETE TO authenticated
  USING (public.can_edit_stock(auth.uid()));

-- uniform_issuances
DROP POLICY IF EXISTS "auth_uniform_issuances" ON public.uniform_issuances;
CREATE POLICY "uniform_issuances_select"
  ON public.uniform_issuances FOR SELECT TO authenticated USING (true);
CREATE POLICY "uniform_issuances_insert"
  ON public.uniform_issuances FOR INSERT TO authenticated
  WITH CHECK (public.can_edit_stock(auth.uid()));
CREATE POLICY "uniform_issuances_update"
  ON public.uniform_issuances FOR UPDATE TO authenticated
  USING (public.can_edit_stock(auth.uid()))
  WITH CHECK (public.can_edit_stock(auth.uid()));
CREATE POLICY "uniform_issuances_delete"
  ON public.uniform_issuances FOR DELETE TO authenticated
  USING (public.can_edit_stock(auth.uid()));
