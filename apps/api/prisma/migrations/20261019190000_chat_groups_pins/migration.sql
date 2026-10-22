-- Group chats, per-user pin, mute, and a private display name.
ALTER TYPE "ChatType" ADD VALUE IF NOT EXISTS 'group';

ALTER TABLE "chat_participants" ADD COLUMN IF NOT EXISTS "pinned_at" TIMESTAMP(3);
ALTER TABLE "chat_participants" ADD COLUMN IF NOT EXISTS "muted_at" TIMESTAMP(3);
ALTER TABLE "chat_participants" ADD COLUMN IF NOT EXISTS "alias" TEXT;
