-- Run after uploading all files from images.zip into Supabase Storage bucket: product-images
-- This converts existing product image filenames into public Supabase Storage URLs.

update public.products
set image_url = 'https://wuylgqlyvvezcfliqrhb.supabase.co/storage/v1/object/public/product-images/' || regexp_replace(image_url, '^images/', '')
where image_url is not null
  and image_url <> ''
  and image_url not like 'http%';

-- Check result
select product_id, name, image_url
from public.products
order by product_id;
