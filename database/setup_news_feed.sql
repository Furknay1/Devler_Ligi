-- 1. Tabloyu oluşturma
CREATE TABLE IF NOT EXISTS public.news_feed (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT,
    category VARCHAR(50) NOT NULL DEFAULT 'genel',
    image_url TEXT,
    youtube_url TEXT,
    author_id UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. RLS Aktifleştirme
ALTER TABLE public.news_feed ENABLE ROW LEVEL SECURITY;

-- 3. Görünürlük Politikası (Herkes görebilir)
CREATE POLICY "News are visible to everyone"
ON public.news_feed FOR SELECT
USING (true);

-- 4. Ekleme Politikası (Sadece admin silebilir/yazabilir)
CREATE POLICY "Only admins can insert news"
ON public.news_feed FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
);

CREATE POLICY "Only admins can update news"
ON public.news_feed FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
);

CREATE POLICY "Only admins can delete news"
ON public.news_feed FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- 5. Storage Ayarları (Eğer yoksa)
INSERT INTO storage.buckets (id, name, public) VALUES ('news_images', 'news_images', true) ON CONFLICT (id) DO NOTHING;

-- Storage public okuma izni (Sadece Giriş Yapmış Olanlar listeleyebilir)
CREATE POLICY "news_images public read" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'news_images');
-- Storage upload izni
CREATE POLICY "news_images auth insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'news_images' AND auth.role() = 'authenticated');
