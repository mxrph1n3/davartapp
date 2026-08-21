-- Sprint 14: client | designer | complectator | admin (migrate staff → complectator)

CREATE TYPE "UserRole_new" AS ENUM ('client', 'designer', 'complectator', 'admin');

ALTER TABLE "users" ALTER COLUMN "role" DROP DEFAULT;

ALTER TABLE "users"
  ALTER COLUMN "role" TYPE "UserRole_new"
  USING (
    CASE
      WHEN "role"::text = 'staff' THEN 'complectator'::"UserRole_new"
      WHEN "role"::text = 'client' THEN 'client'::"UserRole_new"
      ELSE 'client'::"UserRole_new"
    END
  );

DROP TYPE "UserRole";

ALTER TYPE "UserRole_new" RENAME TO "UserRole";

ALTER TABLE "users" ALTER COLUMN "role" SET DEFAULT 'client'::"UserRole";

-- Seed studio phones (idempotent role/name alignment)
UPDATE "users" SET "role" = 'designer', "name" = COALESCE("name", 'Анна Дизайнер')
WHERE "phone" = '+79009999999';

UPDATE "users" SET "role" = 'complectator', "name" = COALESCE("name", 'Ирина Менеджер')
WHERE "phone" = '+79009999998';

UPDATE "users" SET "role" = 'complectator', "name" = COALESCE("name", 'Павел Замерщик')
WHERE "phone" = '+79009999997';

INSERT INTO "users" ("id", "phone", "name", "role", "notifications_enabled", "created_at", "updated_at")
VALUES (
  'a0000000-0000-4000-8000-000000000090',
  '+79009999990',
  'Artur',
  'admin',
  true,
  NOW(),
  NOW()
)
ON CONFLICT ("phone") DO UPDATE
SET
  "role" = 'admin',
  "name" = COALESCE(EXCLUDED."name", "users"."name"),
  "updated_at" = NOW();
