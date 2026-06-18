class SupabaseConfig {
  // Replace these two values with your Supabase project values.
  // Supabase Dashboard -> Project Settings -> API Keys
  static const String url = 'https://wuylgqlyvvezcfliqrhb.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1eWxncWx5dnZlemNmbGlxcmhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE3OTQ1MzAsImV4cCI6MjA5NzM3MDUzMH0.JlFAS6lS120HuNU60niu_DLkeBlDRVaI9PIq04VuhhA';

  // Upload product images to this public Storage bucket.
  static const String publicImageBucket = 'product-images';

  static String imageUrl(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    return '$url/storage/v1/object/public/$publicImageBucket/$value';
  }
}
