-- ========================================================
-- Expense OS Mobile - Supabase Database Schema Migration
-- Project: https://supabase.com/dashboard/project/gtwirhvswhslljbfvnoe/sql
-- ========================================================

-- 1. Create Expenses Table
CREATE TABLE IF NOT EXISTS public.expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    category TEXT NOT NULL DEFAULT 'Miscellaneous',
    type TEXT NOT NULL DEFAULT 'expense',
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_method TEXT NOT NULL DEFAULT 'Card',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable Row Level Security (RLS) for Expenses
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

-- Expenses RLS Policies
CREATE POLICY "Allow public read access to expenses"
    ON public.expenses FOR SELECT
    USING (true);

CREATE POLICY "Allow authenticated and guest inserts to expenses"
    ON public.expenses FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Allow user updates to expenses"
    ON public.expenses FOR UPDATE
    USING (true);

CREATE POLICY "Allow user deletions on expenses"
    ON public.expenses FOR DELETE
    USING (true);


-- 2. Create Subscriptions & Bills Table
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    category TEXT NOT NULL DEFAULT 'Services & Subscriptions',
    cycle TEXT NOT NULL DEFAULT 'monthly',
    due_date DATE NOT NULL,
    payment_method TEXT NOT NULL DEFAULT 'Card',
    is_paid BOOLEAN NOT NULL DEFAULT FALSE,
    last_paid_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable Row Level Security (RLS) for Subscriptions
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- Subscriptions RLS Policies
CREATE POLICY "Allow public access to subscriptions"
    ON public.subscriptions FOR ALL
    USING (true);

-- Indexing for high performance queries
CREATE INDEX IF NOT EXISTS idx_expenses_user_date ON public.expenses (user_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_subscriptions_due ON public.subscriptions (due_date ASC);
