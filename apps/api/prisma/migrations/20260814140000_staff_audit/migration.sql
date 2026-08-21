-- CreateTable
CREATE TABLE "staff_audit_logs" (
    "id" TEXT NOT NULL,
    "actor_id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "meta" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "staff_audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "staff_audit_logs_actor_id_created_at_idx" ON "staff_audit_logs"("actor_id", "created_at");

-- CreateIndex
CREATE INDEX "staff_audit_logs_client_id_created_at_idx" ON "staff_audit_logs"("client_id", "created_at");

-- CreateIndex
CREATE INDEX "staff_audit_logs_created_at_idx" ON "staff_audit_logs"("created_at");

-- AddForeignKey
ALTER TABLE "staff_audit_logs" ADD CONSTRAINT "staff_audit_logs_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "staff_audit_logs" ADD CONSTRAINT "staff_audit_logs_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
