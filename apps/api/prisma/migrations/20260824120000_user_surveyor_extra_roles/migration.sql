-- AlterEnum
ALTER TYPE "UserRole" ADD VALUE IF NOT EXISTS 'surveyor';

-- AlterTable
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "extra_roles" "UserRole"[] DEFAULT ARRAY[]::"UserRole"[];
