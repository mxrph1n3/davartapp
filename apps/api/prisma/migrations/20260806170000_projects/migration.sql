-- CreateEnum
CREATE TYPE "ProjectStatus" AS ENUM ('brief_filling', 'in_progress', 'completed', 'archived');

-- CreateTable
CREATE TABLE "projects" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "designer_id" TEXT,
    "name" TEXT NOT NULL,
    "address" TEXT,
    "area" DOUBLE PRECISION,
    "style" TEXT,
    "start_date" TIMESTAMP(3),
    "status" "ProjectStatus" NOT NULL DEFAULT 'brief_filling',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "projects_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "briefs" (
    "id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL,
    "style" TEXT,
    "budget" DECIMAL(12,2),
    "wishes" TEXT,
    "rooms" JSONB,
    "is_locked" BOOLEAN NOT NULL DEFAULT false,
    "locked_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "briefs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "projects_user_id_idx" ON "projects"("user_id");

-- CreateIndex
CREATE INDEX "projects_designer_id_idx" ON "projects"("designer_id");

-- CreateIndex
CREATE UNIQUE INDEX "briefs_project_id_key" ON "briefs"("project_id");

-- AddForeignKey
ALTER TABLE "projects" ADD CONSTRAINT "projects_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "projects" ADD CONSTRAINT "projects_designer_id_fkey" FOREIGN KEY ("designer_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "briefs" ADD CONSTRAINT "briefs_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "projects"("id") ON DELETE CASCADE ON UPDATE CASCADE;
