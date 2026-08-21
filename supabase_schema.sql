-- ========================================================
-- Expense OS - Unified Multi-App Supabase Database Schema
-- Supports Web, Mobile, Desktop, and Micro-Services
-- Project: https://supabase.com/dashboard/project/gtwirhvswhslljbfvnoe/sql
-- ========================================================

-- Enable UUID extension if not enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- --------------------------------------------------------
-- 1. Profiles Table (User settings, starting balance, currency)
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    full_name TEXT,
    avatar_url TEXT,
    currency TEXT NOT NULL DEFAULT 'INR',
    monthly_budget NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    starting_balance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_profile_user UNIQUE (user_id)
);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'INR';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS monthly_budget NUMERIC(12, 2) NOT NULL DEFAULT 0.00;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS starting_balance NUMERIC(12, 2) NOT NULL DEFAULT 0.00;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read access to profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow authenticated and guest upsert to profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow updates to profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow deletions on profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users manage own profile" ON public.profiles;

CREATE POLICY "Users manage own profile"
    ON public.profiles FOR ALL
    USING (auth.uid() = user_id OR user_id IS NULL)
    WITH CHECK (auth.uid() = user_id OR user_id IS NULL);


-- --------------------------------------------------------
-- 2. Categories Table (Standard and Custom Categories)
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    icon TEXT,
    color TEXT,
    type TEXT NOT NULL DEFAULT 'expense', -- 'expense' or 'income'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public access to categories" ON public.categories;
DROP POLICY IF EXISTS "Users manage own categories" ON public.categories;

CREATE POLICY "Users manage own categories"
    ON public.categories FOR ALL
    USING (auth.uid() = user_id OR user_id IS NULL)
    WITH CHECK (auth.uid() = user_id OR user_id IS NULL);


-- --------------------------------------------------------
-- 3. Expenses & Incomes Table (Transactions Ledger)
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.expenses (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    category TEXT NOT NULL DEFAULT 'Miscellaneous',
    type TEXT NOT NULL DEFAULT 'expense', -- 'expense' or 'income'
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_method TEXT NOT NULL DEFAULT 'Card',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS date DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'expense';
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS payment_method TEXT NOT NULL DEFAULT 'Card';
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS notes TEXT;

ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public access to expenses" ON public.expenses;
DROP POLICY IF EXISTS "Users manage own expenses" ON public.expenses;

CREATE POLICY "Users manage own expenses"
    ON public.expenses FOR ALL
    USING (auth.uid() = user_id OR user_id IS NULL)
    WITH CHECK (auth.uid() = user_id OR user_id IS NULL);


-- --------------------------------------------------------
-- 4. Subscriptions & Recurring Bills Table
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    category TEXT NOT NULL DEFAULT 'Services & Subscriptions',
    cycle TEXT NOT NULL DEFAULT 'monthly', -- 'monthly', 'yearly', 'weekly', 'quarterly', 'one-time'
    due_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,
    payment_method TEXT NOT NULL DEFAULT 'Card',
    is_paid BOOLEAN NOT NULL DEFAULT FALSE,
    last_paid_date DATE,
    remind_on_due_date BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS due_date DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public access to subscriptions" ON public.subscriptions;
DROP POLICY IF EXISTS "Users manage own subscriptions" ON public.subscriptions;

CREATE POLICY "Users manage own subscriptions"
    ON public.subscriptions FOR ALL
    USING (auth.uid() = user_id OR user_id IS NULL)
    WITH CHECK (auth.uid() = user_id OR user_id IS NULL);


-- --------------------------------------------------------
-- 5. Budgets Table (Category & Monthly Budget Caps)
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    category TEXT NOT NULL DEFAULT 'overall',
    amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    period TEXT NOT NULL DEFAULT 'monthly', -- 'monthly', 'weekly', 'yearly'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.budgets ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public access to budgets" ON public.budgets;
DROP POLICY IF EXISTS "Users manage own budgets" ON public.budgets;

CREATE POLICY "Users manage own budgets"
    ON public.budgets FOR ALL
    USING (auth.uid() = user_id OR user_id IS NULL)
    WITH CHECK (auth.uid() = user_id OR user_id IS NULL);


-- --------------------------------------------------------
-- 6. Split Bills Table (Group Expenses)
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.split_bills (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    total_amount NUMERIC(12, 2) NOT NULL,
    paid_by TEXT NOT NULL DEFAULT 'You',
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    members JSONB NOT NULL DEFAULT '["You"]'::jsonb,
    custom_shares JSONB NOT NULL DEFAULT '{}'::jsonb,
    settled_status JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.split_bills ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.split_bills ADD COLUMN IF NOT EXISTS date DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE public.split_bills ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public access to split_bills" ON public.split_bills;
DROP POLICY IF EXISTS "Users manage own split_bills" ON public.split_bills;

CREATE POLICY "Users manage own split_bills"
    ON public.split_bills FOR ALL
    USING (auth.uid() = user_id OR user_id IS NULL)
    WITH CHECK (auth.uid() = user_id OR user_id IS NULL);


-- --------------------------------------------------------
-- 7. Split Bill Members Table (Relational Member Rows)
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.split_bill_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    split_bill_id TEXT REFERENCES public.split_bills(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    amount_owed NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    is_paid BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.split_bill_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public access to split_bill_members" ON public.split_bill_members;
DROP POLICY IF EXISTS "Allow members access via split bill" ON public.split_bill_members;

CREATE POLICY "Allow members access via split bill"
    ON public.split_bill_members FOR ALL USING (true);


-- --------------------------------------------------------
-- 8. Export Templates Table
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.export_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    format TEXT NOT NULL DEFAULT 'csv', -- 'csv', 'pdf', 'excel', 'json'
    config JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.export_templates ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.export_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public access to export_templates" ON public.export_templates;
DROP POLICY IF EXISTS "Users manage own export_templates" ON public.export_templates;

CREATE POLICY "Users manage own export_templates"
    ON public.export_templates FOR ALL
    USING (auth.uid() = user_id OR user_id IS NULL)
    WITH CHECK (auth.uid() = user_id OR user_id IS NULL);


-- --------------------------------------------------------
-- 9. Unified User Data Table (State Document for Web/Mobile sync)
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_data (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    user_id TEXT UNIQUE NOT NULL,
    budget NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    expenses JSONB NOT NULL DEFAULT '[]'::jsonb,
    incomes JSONB NOT NULL DEFAULT '[]'::jsonb,
    subscriptions JSONB NOT NULL DEFAULT '[]'::jsonb,
    currency TEXT NOT NULL DEFAULT 'INR',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.user_data ADD COLUMN IF NOT EXISTS user_id TEXT;

ALTER TABLE public.user_data ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public access to user_data" ON public.user_data;
DROP POLICY IF EXISTS "Users manage own user_data" ON public.user_data;

CREATE POLICY "Users manage own user_data"
    ON public.user_data FOR ALL
    USING (auth.uid()::text = user_id OR user_id IS NULL)
    WITH CHECK (auth.uid()::text = user_id OR user_id IS NULL);


-- --------------------------------------------------------
-- 10. App Updates Table (Over-The-Air Version Management)
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_updates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version TEXT NOT NULL,
    apk_url TEXT NOT NULL,
    changelog TEXT NOT NULL DEFAULT 'Performance improvements and new tools.',
    is_mandatory BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.app_updates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read access to app_updates" ON public.app_updates;
DROP POLICY IF EXISTS "Users read app_updates" ON public.app_updates;

CREATE POLICY "Users read app_updates"
    ON public.app_updates FOR SELECT USING (true);


-- --------------------------------------------------------
-- Indexes for High Performance Real-Time Queries (Safe Blocks)
-- --------------------------------------------------------
DO $$
BEGIN
  BEGIN
    CREATE INDEX IF NOT EXISTS idx_expenses_user_date ON public.expenses (user_id, date DESC);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    CREATE INDEX IF NOT EXISTS idx_expenses_type ON public.expenses (type);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    CREATE INDEX IF NOT EXISTS idx_subscriptions_user_due ON public.subscriptions (user_id, due_date ASC);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    CREATE INDEX IF NOT EXISTS idx_split_bills_user ON public.split_bills (user_id, date DESC);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    CREATE INDEX IF NOT EXISTS idx_split_bill_members_bill ON public.split_bill_members (split_bill_id);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    CREATE INDEX IF NOT EXISTS idx_budgets_user ON public.budgets (user_id);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    CREATE INDEX IF NOT EXISTS idx_user_data_user_id ON public.user_data (user_id);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON public.profiles (user_id);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    CREATE INDEX IF NOT EXISTS idx_app_updates_created ON public.app_updates (created_at DESC);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
END $$;

-- Enable Realtime publication safely (ignores if table is already published)
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.expenses;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.subscriptions;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.split_bills;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.budgets;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.user_data;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.app_updates;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
END $$;
