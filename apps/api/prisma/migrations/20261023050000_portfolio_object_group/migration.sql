-- AlterTable
ALTER TABLE "portfolio_projects" ADD COLUMN     "object_group" TEXT;

-- CreateIndex
CREATE INDEX "portfolio_projects_object_group_idx" ON "portfolio_projects"("object_group");

