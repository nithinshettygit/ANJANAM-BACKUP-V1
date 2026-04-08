-- Admin product reviews moderation listing should stay fast at scale.
-- Supports global newest-first scans used in admin review moderation UI.

create index if not exists idx_reviews_created_at_desc
  on public.reviews (created_at desc);
