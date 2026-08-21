-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('client', 'staff');

-- AlterTable
ALTER TABLE "users" ADD COLUMN "role" "UserRole" NOT NULL DEFAULT 'client';

-- Known studio staff phones → staff role
UPDATE "users"
SET "role" = 'staff'
WHERE "phone" IN (
  '+79009999999',
  '+79009999998',
  '+79009999997'
);
