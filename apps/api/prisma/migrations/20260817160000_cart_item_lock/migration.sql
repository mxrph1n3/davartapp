-- AlterTable
ALTER TABLE "cart_items" ADD COLUMN "locked_at" TIMESTAMP(3),
ADD COLUMN "locked_by_order_id" TEXT;

-- CreateIndex
CREATE INDEX "cart_items_locked_by_order_id_idx" ON "cart_items"("locked_by_order_id");

-- AddForeignKey
ALTER TABLE "cart_items" ADD CONSTRAINT "cart_items_locked_by_order_id_fkey" FOREIGN KEY ("locked_by_order_id") REFERENCES "orders"("id") ON DELETE SET NULL ON UPDATE CASCADE;
