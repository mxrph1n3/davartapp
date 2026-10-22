-- Questionnaire stays a draft until the buyer submits it.
ALTER TABLE "projects" ADD COLUMN "is_draft" BOOLEAN NOT NULL DEFAULT false;

-- A cart is either the buyer's personal basket (user_id) or a project basket.
ALTER TABLE "carts" ALTER COLUMN "project_id" DROP NOT NULL;
ALTER TABLE "carts" ADD COLUMN "user_id" TEXT;

CREATE UNIQUE INDEX "carts_user_id_key" ON "carts"("user_id");

ALTER TABLE "carts"
  ADD CONSTRAINT "carts_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
