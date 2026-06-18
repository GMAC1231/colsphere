-- CLOSPHERE Direct Supabase Setup
-- Run in Supabase SQL Editor before using the no-backend Flutter lib.

-- 1) Profiles connected to Supabase Auth
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  email text not null unique,
  role text not null default 'user',
  ghala_score integer not null default 2450,
  created_at timestamptz not null default now()
);

-- 2) Make user_id compatible with Supabase Auth UUID
alter table public.cart drop constraint if exists cart_user_id_fkey;
alter table public.cart alter column user_id type uuid using null;
alter table public.cart add constraint cart_user_id_fkey foreign key (user_id) references auth.users(id) on delete cascade;

alter table public.orders drop constraint if exists orders_user_id_fkey;
alter table public.orders alter column user_id type uuid using null;
alter table public.orders add constraint orders_user_id_fkey foreign key (user_id) references auth.users(id) on delete set null;

alter table public.feedback drop constraint if exists feedback_user_id_fkey;
alter table public.feedback alter column user_id type uuid using null;
alter table public.feedback add constraint feedback_user_id_fkey foreign key (user_id) references auth.users(id) on delete set null;

-- 3) Columns used by Flutter direct checkout/admin revenue
alter table public.orders add column if not exists price_omr text;
alter table public.orders add column if not exists total_amount text;

-- 4) Useful indexes
create index if not exists idx_profiles_email on public.profiles(email);
create index if not exists idx_cart_user_id on public.cart(user_id);
create index if not exists idx_orders_user_id on public.orders(user_id);
create index if not exists idx_feedback_user_id on public.feedback(user_id);

-- 5) Enable Row Level Security for direct Flutter access
alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.cart enable row level security;
alter table public.orders enable row level security;
alter table public.feedback enable row level security;
alter table public.rentals enable row level security;

-- 6) Reset duplicate policies safely
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Anyone can view products" ON public.products;
DROP POLICY IF EXISTS "Admin can manage products" ON public.products;
DROP POLICY IF EXISTS "Users can read own cart" ON public.cart;
DROP POLICY IF EXISTS "Users can insert own cart" ON public.cart;
DROP POLICY IF EXISTS "Users can delete own cart" ON public.cart;
DROP POLICY IF EXISTS "Users can read own orders" ON public.orders;
DROP POLICY IF EXISTS "Users can create own orders" ON public.orders;
DROP POLICY IF EXISTS "Admin can read all orders" ON public.orders;
DROP POLICY IF EXISTS "Admin can update orders" ON public.orders;
DROP POLICY IF EXISTS "Admin can delete orders" ON public.orders;
DROP POLICY IF EXISTS "Users can create own feedback" ON public.feedback;
DROP POLICY IF EXISTS "Admin can read feedback" ON public.feedback;
DROP POLICY IF EXISTS "Admin can delete feedback" ON public.feedback;
DROP POLICY IF EXISTS "Users can read own rentals" ON public.rentals;
DROP POLICY IF EXISTS "Admin can read all rentals" ON public.rentals;

-- Profiles
create policy "Users can read own profile"
on public.profiles for select
to authenticated
using (auth.uid() = id);

create policy "Users can insert own profile"
on public.profiles for insert
to authenticated
with check (auth.uid() = id);

create policy "Users can update own profile"
on public.profiles for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

-- Products
create policy "Anyone can view products"
on public.products for select
to anon, authenticated
using (true);

create policy "Admin can manage products"
on public.products for all
to authenticated
using (exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin'))
with check (exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin'));

-- Cart
create policy "Users can read own cart"
on public.cart for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can insert own cart"
on public.cart for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can delete own cart"
on public.cart for delete
to authenticated
using (auth.uid() = user_id);

-- Orders
create policy "Users can read own orders"
on public.orders for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can create own orders"
on public.orders for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Admin can read all orders"
on public.orders for select
to authenticated
using (exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin'));

create policy "Admin can update orders"
on public.orders for update
to authenticated
using (exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin'))
with check (exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin'));

create policy "Admin can delete orders"
on public.orders for delete
to authenticated
using (exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin'));

-- Feedback
create policy "Users can create own feedback"
on public.feedback for insert
to authenticated
with check (auth.uid() = user_id or user_id is null);

create policy "Admin can read feedback"
on public.feedback for select
to authenticated
using (exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin'));

create policy "Admin can delete feedback"
on public.feedback for delete
to authenticated
using (exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin'));

-- Rentals legacy table
create policy "Users can read own rentals"
on public.rentals for select
to authenticated
using (true);

create policy "Admin can read all rentals"
on public.rentals for select
to authenticated
using (exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin'));
