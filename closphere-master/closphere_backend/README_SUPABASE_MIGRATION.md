# CLOSPHERE backend moved to Supabase

This version keeps the same Express REST API endpoints used by Flutter, but replaces SQLite (`closphere.db`) with Supabase Postgres.

## 1. Create Supabase tables
Open Supabase Dashboard > SQL Editor and run:

```sql
-- paste contents of supabase_schema.sql
```

## 2. Set backend environment variables
Create `.env` from `.env.example`:

```env
SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY_HERE
PORT=3000
HOST=0.0.0.0
```

Use the **service role key only in backend**. Never put it in Flutter.

## 3. Install and run

```bash
npm install
npm start
```

On first startup, the backend seeds:
- admin user: `omar@closphere.com / password123`
- products from `products.csv` if products table is empty

## 4. Flutter URL
In Flutter, edit:

```dart
lib/core/api_config.dart
```

Set `baseUrl` to your deployed backend URL, for example:

```dart
static const String baseUrl = 'https://your-backend.onrender.com';
```

Do not point Flutter directly to Supabase for this version. Flutter still calls your Express API.
