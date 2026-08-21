-- Sprint 16: Cart bound to Project (ARCH-01)

-- 1) Add project_id to carts (nullable during backfill)
ALTER TABLE "carts" ADD COLUMN "project_id" TEXT;

-- 2) Map existing user carts → primary / latest non-showcase project
UPDATE "carts" c
SET "project_id" = (
  SELECT p."id"
  FROM "projects" p
  WHERE p."is_showcase" = false
    AND (
      p."user_id" = c."user_id"
      OR EXISTS (
        SELECT 1 FROM "project_members" pm
        WHERE pm."project_id" = p."id" AND pm."user_id" = c."user_id"
      )
    )
  ORDER BY p."updated_at" DESC
  LIMIT 1
);

-- 3) Drop carts that could not be mapped (no project)
DELETE FROM "cart_items"
WHERE "cart_id" IN (SELECT "id" FROM "carts" WHERE "project_id" IS NULL);

DELETE FROM "carts" WHERE "project_id" IS NULL;

-- 4) If multiple carts mapped to same project, keep the newest
DELETE FROM "cart_items"
WHERE "cart_id" IN (
  SELECT c."id" FROM "carts" c
  WHERE c."project_id" IS NOT NULL
    AND c."id" NOT IN (
      SELECT DISTINCT ON (c2."project_id") c2."id"
      FROM "carts" c2
      WHERE c2."project_id" IS NOT NULL
      ORDER BY c2."project_id", c2."updated_at" DESC
    )
);

DELETE FROM "carts"
WHERE "id" NOT IN (
  SELECT DISTINCT ON ("project_id") "id"
  FROM "carts"
  WHERE "project_id" IS NOT NULL
  ORDER BY "project_id", "updated_at" DESC
)
AND "project_id" IS NOT NULL;

-- 5) Drop user_id, enforce project_id
ALTER TABLE "carts" DROP CONSTRAINT IF EXISTS "carts_user_id_fkey";
DROP INDEX IF EXISTS "carts_user_id_key";
ALTER TABLE "carts" DROP COLUMN "user_id";

ALTER TABLE "carts" ALTER COLUMN "project_id" SET NOT NULL;

CREATE UNIQUE INDEX "carts_project_id_key" ON "carts"("project_id");

ALTER TABLE "carts"
  ADD CONSTRAINT "carts_project_id_fkey"
  FOREIGN KEY ("project_id") REFERENCES "projects"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

-- 6) Orders optionally link to project
ALTER TABLE "orders" ADD COLUMN "project_id" TEXT;

CREATE INDEX "orders_project_id_idx" ON "orders"("project_id");

ALTER TABLE "orders"
  ADD CONSTRAINT "orders_project_id_fkey"
  FOREIGN KEY ("project_id") REFERENCES "projects"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
