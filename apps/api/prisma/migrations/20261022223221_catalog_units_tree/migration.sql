-- AlterTable
ALTER TABLE "categories" ADD COLUMN     "parent_id" TEXT;

-- AlterTable
ALTER TABLE "products" ADD COLUMN     "images" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "lead_time_max_days" INTEGER,
ADD COLUMN     "lead_time_min_days" INTEGER,
ADD COLUMN     "pack_pieces" INTEGER,
ADD COLUMN     "pack_size" DECIMAL(10,4),
ADD COLUMN     "sell_by_pack" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "unit" TEXT NOT NULL DEFAULT 'шт';

-- CreateIndex
CREATE INDEX "categories_parent_id_idx" ON "categories"("parent_id");

-- AddForeignKey
ALTER TABLE "categories" ADD CONSTRAINT "categories_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "categories"("id") ON DELETE SET NULL ON UPDATE CASCADE;
