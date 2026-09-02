-- Project member relation label (кем приходится).
ALTER TABLE "project_members" ADD COLUMN IF NOT EXISTS "relation" TEXT;

-- Chat reply / pin.
ALTER TABLE "messages" ADD COLUMN IF NOT EXISTS "reply_to_id" TEXT;
ALTER TABLE "messages" ADD COLUMN IF NOT EXISTS "is_pinned" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "messages" ADD COLUMN IF NOT EXISTS "pinned_at" TIMESTAMP(3);

DO $$ BEGIN
  ALTER TABLE "messages"
    ADD CONSTRAINT "messages_reply_to_id_fkey"
    FOREIGN KEY ("reply_to_id") REFERENCES "messages"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS "messages_chat_id_is_pinned_idx" ON "messages"("chat_id", "is_pinned");

-- Message reactions.
CREATE TABLE IF NOT EXISTS "message_reactions" (
    "id" TEXT NOT NULL,
    "message_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "emoji" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "message_reactions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "message_reactions_message_id_user_id_emoji_key"
  ON "message_reactions"("message_id", "user_id", "emoji");
CREATE INDEX IF NOT EXISTS "message_reactions_message_id_idx"
  ON "message_reactions"("message_id");

DO $$ BEGIN
  ALTER TABLE "message_reactions"
    ADD CONSTRAINT "message_reactions_message_id_fkey"
    FOREIGN KEY ("message_id") REFERENCES "messages"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE "message_reactions"
    ADD CONSTRAINT "message_reactions_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
