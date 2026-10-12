-- Hide a chat for one user without letting project sync recreate it.
ALTER TABLE "projects" ADD COLUMN "project_chat_dismissed" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "chat_participants" ADD COLUMN "hidden_at" TIMESTAMP(3);
