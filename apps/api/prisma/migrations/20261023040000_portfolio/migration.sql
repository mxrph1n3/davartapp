-- CreateEnum
CREATE TYPE "PortfolioKind" AS ENUM ('full', 'basic', 'exterior', 'architecture', 'landscape');

-- CreateTable
CREATE TABLE "portfolio_projects" (
    "id" TEXT NOT NULL,
    "number" TEXT NOT NULL,
    "kind" "PortfolioKind" NOT NULL DEFAULT 'full',
    "title" TEXT NOT NULL,
    "object_type" TEXT,
    "style" TEXT,
    "area" DOUBLE PRECISION,
    "rooms" TEXT[],
    "designer" TEXT,
    "completed_at" TIMESTAMP(3),
    "materials_cost" DECIMAL(12,2),
    "description" TEXT,
    "in_realization" BOOLEAN NOT NULL DEFAULT false,
    "published" BOOLEAN NOT NULL DEFAULT false,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "portfolio_projects_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "portfolio_images" (
    "id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "room" TEXT,
    "is_plan" BOOLEAN NOT NULL DEFAULT false,
    "width" INTEGER,
    "height" INTEGER,
    "sort_order" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "portfolio_images_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "portfolio_styles" (
    "slug" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "cover_key" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "portfolio_styles_pkey" PRIMARY KEY ("slug")
);

-- CreateTable
CREATE TABLE "portfolio_favorites" (
    "user_id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "portfolio_favorites_pkey" PRIMARY KEY ("user_id","project_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "portfolio_projects_number_key" ON "portfolio_projects"("number");

-- CreateIndex
CREATE INDEX "portfolio_projects_style_idx" ON "portfolio_projects"("style");

-- CreateIndex
CREATE INDEX "portfolio_projects_kind_idx" ON "portfolio_projects"("kind");

-- CreateIndex
CREATE INDEX "portfolio_images_project_id_sort_order_idx" ON "portfolio_images"("project_id", "sort_order");

-- AddForeignKey
ALTER TABLE "portfolio_images" ADD CONSTRAINT "portfolio_images_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "portfolio_projects"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "portfolio_favorites" ADD CONSTRAINT "portfolio_favorites_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "portfolio_favorites" ADD CONSTRAINT "portfolio_favorites_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "portfolio_projects"("id") ON DELETE CASCADE ON UPDATE CASCADE;

