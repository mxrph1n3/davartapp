-- AlterTable
ALTER TABLE "projects" ADD COLUMN "number" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "projects_number_key" ON "projects"("number");
