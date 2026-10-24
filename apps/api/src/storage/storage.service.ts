import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  CreateBucketCommand,
  GetObjectCommand,
  HeadBucketCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

@Injectable()
export class StorageService implements OnModuleInit {
  private readonly logger = new Logger(StorageService.name);
  /** Internal Docker network client (http://minio:9000) — Put/Head only. */
  private client: S3Client | null = null;
  /**
   * Client whose endpoint is the phone-reachable MinIO origin.
   * Presigned URLs must be signed for this host — rewriting Host after
   * signing breaks SigV4 (X-Amz-SignedHeaders includes host).
   */
  private signingClient: S3Client | null = null;
  private bucket = 'davart';
  private enabled = false;

  constructor(private readonly config: ConfigService) {}

  async onModuleInit() {
    const endpoint = this.config.get<string>('S3_ENDPOINT');
    const accessKey = this.config.get<string>('S3_ACCESS_KEY');
    const secretKey = this.config.get<string>('S3_SECRET_KEY');

    if (!endpoint || !accessKey || !secretKey) {
      this.logger.warn('S3 not configured — file storage disabled');
      return;
    }

    this.bucket = this.config.get<string>('S3_BUCKET', 'davart');
    const region = this.config.get<string>('S3_REGION', 'us-east-1');
    const credentials = {
      accessKeyId: accessKey,
      secretAccessKey: secretKey,
    };

    this.client = new S3Client({
      endpoint,
      region,
      credentials,
      forcePathStyle: true,
    });

    const publicOrigin = this.resolvePublicOrigin(endpoint);
    this.signingClient = new S3Client({
      endpoint: publicOrigin,
      region,
      credentials,
      forcePathStyle: true,
    });
    this.logger.log(`S3 signing endpoint: ${publicOrigin}`);

    try {
      await this.client.send(new HeadBucketCommand({ Bucket: this.bucket }));
      this.enabled = true;
      this.logger.log(`S3 bucket "${this.bucket}" ready`);
    } catch {
      try {
        await this.client.send(
          new CreateBucketCommand({ Bucket: this.bucket }),
        );
        this.enabled = true;
        this.logger.log(`S3 bucket "${this.bucket}" created`);
      } catch (error) {
        this.logger.warn(`S3 unavailable: ${error}`);
      }
    }
  }

  isAvailable(): boolean {
    return this.enabled && this.client !== null && this.signingClient !== null;
  }

  async getUploadUrl(
    storageKey: string,
    contentType: string,
    expiresIn = 900,
  ): Promise<string> {
    this.ensureAvailable();

    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: storageKey,
      ContentType: contentType,
    });

    return getSignedUrl(this.signingClient!, command, { expiresIn });
  }

  async getDownloadUrl(storageKey: string, expiresIn = 1800): Promise<string> {
    this.ensureAvailable();

    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: storageKey,
    });

    return getSignedUrl(this.signingClient!, command, { expiresIn });
  }

  async uploadObject(
    storageKey: string,
    body: Buffer,
    contentType: string,
  ): Promise<void> {
    this.ensureAvailable();

    await this.client!.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: storageKey,
        Body: body,
        ContentType: contentType,
      }),
    );
  }

  /** Public URL for objects meant to be readable without signing (avatars, catalog). */
  publicUrl(storageKey: string): string {
    const base = this.config
      .get<string>('S3_PUBLIC_BASE_URL')
      ?.replace(/\/$/, '');
    if (!base) throw new Error('S3_PUBLIC_BASE_URL is not set');
    return `${base}/${storageKey}`;
  }

  private ensureAvailable() {
    if (!this.isAvailable()) {
      throw new Error('S3 storage is not available');
    }
  }

  /** Origin phones use for MinIO (never rewrite signed URLs after this). */
  private resolvePublicOrigin(internalEndpoint: string): string {
    const publicBase = this.config.get<string>('S3_PUBLIC_BASE_URL')?.trim();
    if (publicBase) {
      try {
        return new URL(publicBase).origin;
      } catch {
        this.logger.warn(`Invalid S3_PUBLIC_BASE_URL="${publicBase}"`);
      }
    }
    try {
      return new URL(internalEndpoint).origin;
    } catch {
      return internalEndpoint;
    }
  }
}
