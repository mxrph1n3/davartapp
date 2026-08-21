-- Sprint 19: Italon ingest identity + collection filter
ALTER TABLE "products" ADD COLUMN "supplier_sku" TEXT;
ALTER TABLE "products" ADD COLUMN "collection_slug" TEXT;
ALTER TABLE "products" ADD COLUMN "source_url" TEXT;

CREATE UNIQUE INDEX "products_supplier_sku_key" ON "products"("supplier_sku");
CREATE INDEX "products_collection_slug_idx" ON "products"("collection_slug");
