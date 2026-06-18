require('dotenv').config();

const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const { createClient } = require('@supabase/supabase-js');

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

app.use(cors());
app.use(express.json());
app.use('/images', express.static(path.join(__dirname, 'public', 'images')));

app.use((req, res, next) => {
  console.log(`📡 [${new Date().toLocaleTimeString()}] ${req.method} ${req.url}`);
  next();
});

function parseCSVLine(line) {
  const result = [];
  let current = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') inQuotes = !inQuotes;
    else if (char === ',' && !inQuotes) {
      result.push(current.trim());
      current = '';
    } else current += char;
  }
  result.push(current.trim());
  return result;
}

function normalizeId(value) {
  if (value === undefined || value === null || value === '') return null;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : null;
}

function getUserId(req) {
  return normalizeId(req.headers['user-id']);
}

function handleSupabaseError(res, error, status = 500) {
  console.error('❌ SUPABASE ERROR:', error);
  return res.status(status).json({ error: error.message || 'Database error' });
}

async function initializeOperationalData() {
  console.log('📦 CONNECTED TO SUPABASE DATABASE.');

  const { count: userCount, error: userCountError } = await supabase
    .from('users')
    .select('id', { count: 'exact', head: true });

  if (userCountError) {
    console.error('❌ Could not read users table. Did you run supabase_schema.sql?', userCountError.message);
    return;
  }

  if ((userCount || 0) === 0) {
    const { error } = await supabase.from('users').insert({
      name: 'OMAR ABDIGANI ALI',
      email: 'omar@closphere.com',
      password: 'password123',
      ghala_score: 2450,
    });
    if (error) console.error('❌ Admin seed failed:', error.message);
    else console.log('🌱 Seeded Default Admin Profile (omar@closphere.com / password123)');
  }

  const { count: productCount, error: productCountError } = await supabase
    .from('products')
    .select('product_id', { count: 'exact', head: true });

  if (productCountError) {
    console.error('❌ Could not read products table:', productCountError.message);
    return;
  }

  if ((productCount || 0) === 0) {
    const csvPath = path.join(__dirname, 'products.csv');
    if (!fs.existsSync(csvPath)) {
      console.log('⚠️ products.csv file not found. Skipping product seed.');
      return;
    }

    const lines = fs.readFileSync(csvPath, 'utf-8').split('\n');
    const products = [];
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line) continue;
      const columns = parseCSVLine(line);
      if (columns.length < 7) continue;
      products.push({
        name: columns[0],
        price_omr: columns[1],
        mode: columns[2],
        condition: columns[3],
        status: columns[4],
        description: columns[5],
        image_url: columns[6],
      });
    }

    if (products.length > 0) {
      const { error } = await supabase.from('products').insert(products);
      if (error) console.error('❌ Product seed failed:', error.message);
      else console.log(`🎉 Seeded ${products.length} products from products.csv.`);
    }
  }
}

// System metadata used by about_page.dart
app.get('/api/system/info', (req, res) => {
  res.json({
    ceo: 'OMAR ABDIGANI ALI',
    division: 'CLOSPHERE GLOBAL',
    database: 'Supabase Postgres',
    status: 'ONLINE',
  });
});

app.post('/api/feedback', async (req, res) => {
  const { user_id, type, message } = req.body;
  if (!message || !message.toString().trim()) {
    return res.status(400).json({ error: 'Feedback message is required.' });
  }

  const { data, error } = await supabase
    .from('feedback')
    .insert({
      user_id: normalizeId(user_id),
      type: type || 'GENERAL FEEDBACK',
      message: message.toString().trim(),
    })
    .select('id')
    .single();

  if (error) return handleSupabaseError(res, error);
  res.status(201).json({ message: 'Ticket logged into Closphere core systems successfully.', id: data.id });
});

app.get('/api/admin/feedback', async (req, res) => {
  const { data: feedbackRows, error } = await supabase
    .from('feedback')
    .select('id,user_id,type,message,timestamp')
    .order('id', { ascending: false });

  if (error) return handleSupabaseError(res, error);

  const userIds = [...new Set((feedbackRows || []).map(f => f.user_id).filter(Boolean))];
  let userMap = new Map();

  if (userIds.length > 0) {
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('id,name,email')
      .in('id', userIds);
    if (usersError) return handleSupabaseError(res, usersError);
    userMap = new Map((users || []).map(u => [u.id, u]));
  }

  const rows = (feedbackRows || []).map(f => {
    const user = userMap.get(f.user_id);
    return {
      ...f,
      client_name: user?.name || 'GUEST USER',
      client_gmail: user?.email || 'N/A',
    };
  });

  res.json(rows);
});

app.delete('/api/admin/feedback/:id', async (req, res) => {
  const { error } = await supabase.from('feedback').delete().eq('id', req.params.id);
  if (error) return handleSupabaseError(res, error);
  res.status(200).json({ message: 'Assistance entry successfully closed and cleared.' });
});

app.get('/api/products', async (req, res) => {
  const { data, error } = await supabase
    .from('products')
    .select('*')
    .order('product_id', { ascending: false });
  if (error) return handleSupabaseError(res, error);
  res.json(data || []);
});

app.post('/api/products', async (req, res) => {
  const { name, price_omr, mode, condition, status, image_url, description } = req.body;
  const { data, error } = await supabase
    .from('products')
    .insert({ name, price_omr, mode, condition, status, image_url, description: description || '' })
    .select('product_id')
    .single();
  if (error) return handleSupabaseError(res, error);
  res.status(201).json({ message: 'Success', id: data.product_id });
});

app.put('/api/products/:id', async (req, res) => {
  const { name, price_omr, mode, condition, status, description } = req.body;
  const { data, error } = await supabase
    .from('products')
    .update({ name, price_omr, mode, condition, status, description: description || '' })
    .eq('product_id', req.params.id)
    .select('product_id');
  if (error) return handleSupabaseError(res, error);
  if (!data || data.length === 0) return res.status(404).json({ error: 'Product record not discovered.' });
  res.status(200).json({ message: 'Product record fully synchronized successfully.' });
});

app.delete('/api/products/:id', async (req, res) => {
  const productId = req.params.id;
  if (!productId || productId === 'null' || productId === 'undefined') {
    return res.status(400).json({ error: 'Missing or corrupted product database row identity.' });
  }
  const { data, error } = await supabase
    .from('products')
    .delete()
    .eq('product_id', productId)
    .select('product_id');
  if (error) return handleSupabaseError(res, error);
  if (!data || data.length === 0) return res.status(404).json({ error: 'No matching record discovered in current engine scope.' });
  res.status(200).json({ message: 'Product record completely dropped and cleared.' });
});

app.post('/api/cart', async (req, res) => {
  const { name, price_omr, mode, image_url } = req.body;
  const { data, error } = await supabase
    .from('cart')
    .insert({ name, price_omr, mode, image_url })
    .select('cart_item_id')
    .single();
  if (error) return handleSupabaseError(res, error);
  res.status(201).json({ message: 'Success', cart_item_id: data.cart_item_id });
});

app.get('/api/cart', async (req, res) => {
  const { data, error } = await supabase
    .from('cart')
    .select('*')
    .order('cart_item_id', { ascending: false });
  if (error) return handleSupabaseError(res, error);
  res.json(data || []);
});

app.delete('/api/cart/clear', async (req, res) => {
  const { error } = await supabase.from('cart').delete().neq('cart_item_id', 0);
  if (error) return handleSupabaseError(res, error);
  res.status(200).json({ message: 'Cart cleared successfully.' });
});

app.delete('/api/cart/:id', async (req, res) => {
  const { error } = await supabase.from('cart').delete().eq('cart_item_id', req.params.id);
  if (error) return handleSupabaseError(res, error);
  res.status(200).json({ message: 'Item successfully removed from archive bag.' });
});

app.post('/api/login', async (req, res) => {
  const { email, password } = req.body;
  const formattedEmail = (email || '').toLowerCase().trim();

  const { data: row, error } = await supabase
    .from('users')
    .select('id,name,email,ghala_score,password')
    .eq('email', formattedEmail)
    .eq('password', password)
    .maybeSingle();

  if (error) return handleSupabaseError(res, error);
  if (!row) return res.status(401).json({ error: 'Invalid credentials.' });

  const isUserAdmin = row.email.toLowerCase().trim() === 'omar@closphere.com';
  res.status(200).json({
    message: 'Welcome back!',
    user: {
      id: row.id,
      name: row.name,
      email: row.email,
      ghala_score: row.ghala_score,
      isGhalaAdmin: isUserAdmin,
    },
  });
});

app.post('/api/register', async (req, res) => {
  const { name, email, password } = req.body;
  const formattedName = (name || '').toUpperCase();
  const formattedEmail = (email || '').toLowerCase().trim();

  const { data, error } = await supabase
    .from('users')
    .insert({ name: formattedName, email: formattedEmail, password, ghala_score: 2450 })
    .select('id,name,email')
    .single();

  if (error) {
    if ((error.message || '').toLowerCase().includes('duplicate')) {
      return res.status(400).json({ error: 'Email already exists.' });
    }
    return handleSupabaseError(res, error);
  }
  res.status(201).json({ message: 'Success', user: data });
});

app.get('/api/users/me', async (req, res) => {
  const userId = getUserId(req);
  let query = supabase.from('users').select('id,name,email,ghala_score');
  query = userId ? query.eq('id', userId).maybeSingle() : query.order('id', { ascending: true }).limit(1).maybeSingle();
  const { data, error } = await query;
  if (error) return handleSupabaseError(res, error);
  res.json(data || { name: 'GUEST USER', email: '', ghala_score: 2450 });
});

app.post('/api/checkout', async (req, res) => {
  const userId = getUserId(req);
  const { rental_start, rental_end, order_type } = req.body;

  const { data: rows, error: cartError } = await supabase.from('cart').select('cart_item_id,name');
  if (cartError) return handleSupabaseError(res, cartError);
  if (!rows || rows.length === 0) return res.status(400).json({ error: 'Your Closphere Bag contains no active entries.' });

  const itemNames = rows.map(r => r.name).join(', ');
  const orderNum = 'CLO-' + Math.floor(100000 + Math.random() * 900000);
  const codeNum = Math.floor(100 + Math.random() * 900) + '-' + Math.floor(100 + Math.random() * 900);

  const { error: orderError } = await supabase.from('orders').insert({
    order_id: orderNum,
    user_id: userId,
    product_name: itemNames,
    pickup_code: codeNum,
    rental_start: rental_start || '---',
    rental_end: rental_end || '---',
    order_type: order_type || 'RENT',
    status: 'ACTIVE',
  });
  if (orderError) return handleSupabaseError(res, orderError);

  await supabase.from('cart').delete().neq('cart_item_id', 0);

  res.status(201).json({
    message: 'Order finalized.',
    order_id: orderNum,
    pickup_code: codeNum,
    product_name: itemNames,
  });
});

app.get('/api/orders', async (req, res) => {
  const userId = getUserId(req);
  if (!userId) return res.status(400).json({ error: 'Missing identity reference header context.' });
  const { data, error } = await supabase.from('orders').select('*').eq('user_id', userId).order('id', { ascending: false });
  if (error) return handleSupabaseError(res, error);
  res.json(data || []);
});

app.get('/api/rentals', async (req, res) => {
  const userId = getUserId(req);
  if (!userId) return res.status(400).json({ error: 'Missing identity reference header context.' });

  const { data: user, error: userError } = await supabase.from('users').select('email').eq('id', userId).maybeSingle();
  if (userError) return handleSupabaseError(res, userError);

  const isAdmin = user?.email?.toLowerCase().trim() === 'omar@closphere.com';
  let query = supabase.from('orders').select('*').order('id', { ascending: false });
  if (!isAdmin) query = query.eq('user_id', userId);
  const { data, error } = await query;
  if (error) return handleSupabaseError(res, error);
  res.status(200).json(data || []);
});

app.get('/api/orders/latest', async (req, res) => {
  const userId = getUserId(req);
  const isAdminMode = req.headers['admin-mode'] === 'true';
  if (!userId) return res.status(400).json({ error: 'Missing identity reference header context.' });

  if (isAdminMode) {
    const { data, error } = await supabase
      .from('orders')
      .select('order_id,product_name,pickup_code,user_id')
      .eq('status', 'ACTIVE')
      .order('id', { ascending: false });
    if (error) return handleSupabaseError(res, error);
    return res.status(200).json(data || []);
  }

  const { data, error } = await supabase
    .from('orders')
    .select('order_id,product_name,pickup_code')
    .eq('user_id', userId)
    .order('id', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) return handleSupabaseError(res, error);
  if (!data) return res.status(404).json({ message: 'No active passes generated.' });
  res.status(200).json(data);
});

app.get('/api/orders/history', async (req, res) => {
  const { data, error } = await supabase
    .from('orders')
    .select('order_id,product_name,pickup_code,user_id,rental_start,rental_end,order_type,status')
    .eq('status', 'COLLECTED')
    .order('id', { ascending: false });
  if (error) return handleSupabaseError(res, error);
  res.status(200).json(data || []);
});

app.delete('/api/orders/history/:id', async (req, res) => {
  const { error } = await supabase.from('orders').delete().eq('order_id', req.params.id);
  if (error) return handleSupabaseError(res, error);
  res.status(200).json({ message: 'History log entry cleanly purged from system.' });
});

app.post('/api/orders/fulfill', async (req, res) => {
  const { order_id, status } = req.body;
  if (!order_id) return res.status(400).json({ error: 'Missing target order_id parameter.' });

  const { data, error } = await supabase
    .from('orders')
    .update({ status: status || 'COLLECTED' })
    .eq('order_id', order_id)
    .select('order_id');
  if (error) return handleSupabaseError(res, error);
  if (!data || data.length === 0) return res.status(404).json({ error: 'No matching invoice pass discovered.' });
  res.status(200).json({ message: 'PASS AUTHENTICATED • CONTEXT TRACKED' });
});

app.delete('/api/admin/orders/:id', async (req, res) => {
  const { data, error } = await supabase.from('orders').delete().eq('id', req.params.id).select('id');
  if (error) return handleSupabaseError(res, error);
  if (!data || data.length === 0) return res.status(404).json({ error: 'No matching transaction record discovered to purge.' });
  res.status(200).json({ message: 'Transaction entry successfully terminated and cleared from log.' });
});

app.post('/api/users/change-password', async (req, res) => {
  const { oldPassword, newPassword } = req.body;
  const userId = getUserId(req);
  if (!userId) return res.status(400).json({ error: 'Missing user identification reference tracking.' });

  const { data: row, error } = await supabase.from('users').select('id,password').eq('id', userId).maybeSingle();
  if (error) return handleSupabaseError(res, error);
  if (!row) return res.status(404).json({ error: 'User profile records not found.' });
  if (row.password !== oldPassword) return res.status(401).json({ error: 'Current password verification mismatch.' });

  const { error: updateError } = await supabase.from('users').update({ password: newPassword }).eq('id', userId);
  if (updateError) return handleSupabaseError(res, updateError);
  res.status(200).json({ message: 'Password updated successfully.' });
});

initializeOperationalData().finally(() => {
  app.listen(PORT, HOST, () => {
    console.log(`📡 BACKEND SUPABASE SYSTEM ACTIVE ON http://${HOST}:${PORT}`);
  });
});
