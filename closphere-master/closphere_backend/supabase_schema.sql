-- CLOSPHERE Supabase schema
-- Run this in Supabase Dashboard > SQL Editor before starting the backend.

create table if not exists public.users (
  id bigserial primary key,
  name text not null,
  email text not null unique,
  password text not null,
  ghala_score integer not null default 2450,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  product_id bigserial primary key,
  name text,
  price_omr text,
  mode text,
  condition text,
  status text,
  description text,
  image_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.cart (
  cart_item_id bigserial primary key,
  user_id bigint null references public.users(id) on delete cascade,
  name text not null,
  price_omr text not null,
  mode text not null,
  image_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id bigserial primary key,
  order_id text not null unique,
  user_id bigint null references public.users(id) on delete set null,
  product_name text not null,
  pickup_code text not null,
  status text not null default 'ACTIVE',
  rental_start text default '---',
  rental_end text default '---',
  order_type text default 'RENT',
  created_at timestamptz not null default now()
);

create table if not exists public.feedback (
  id bigserial primary key,
  user_id bigint null references public.users(id) on delete set null,
  type text default 'GENERAL FEEDBACK',
  message text not null,
  timestamp timestamptz not null default now()
);

create table if not exists public.rentals (
  id bigserial primary key,
  product_name text not null,
  status text not null,
  date_label text not null,
  created_at timestamptz not null default now()
);

-- Useful indexes
create index if not exists idx_orders_user_id on public.orders(user_id);
create index if not exists idx_orders_status on public.orders(status);
create index if not exists idx_feedback_timestamp on public.feedback(timestamp desc);

-- For this Express backend, use the SERVICE_ROLE_KEY server-side.
-- Keep Supabase RLS disabled for these tables while your Express API controls access.
-- Do NOT expose SERVICE_ROLE_KEY in Flutter.
