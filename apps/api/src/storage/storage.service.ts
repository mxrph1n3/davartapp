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
  private client: S3Client | null = null;
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

    this.client = new S3Client({
      endpoint,
      region,
      credentials: { accessKeyId: accessKey, secretAccessKey: secretKey },
      forcePathStyle: true,
    });

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
    return this.enabled && this.client !== null;
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

    const signed = await getSignedUrl(this.client!, command, { expiresIn });
    return this.toPublicUrl(signed);
  }

  async getDownloadUrl(storageKey: string, expiresIn = 1800): Promise<string> {
    this.ensureAvailable();

    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: storageKey,
    });

    const signed = await getSignedUrl(this.client!, command, { expiresIn });
    return this.toPublicUrl(signed);
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

  private ensureAvailable() {
    if (!this.isAvailable()) {
      throw new Error('S3 storage is not available');
    }
  }

  /** Phones cannot reach http://minio:9000 — rewrite host to S3_PUBLIC_BASE_URL. */
  private toPublicUrl(signedUrl: string): string {
    const publicBase = this.config.get<string>('S3_PUBLIC_BASE_URL')?.trim();
    if (!publicBase) return signedUrl;

    try {
      const signed = new URL(signedUrl);
      const pub = new URL(publicBase);
      signed.protocol = pub.protocol;
      signed.host = pub.host;
      return signed.toString();
    } catch {
      return signedUrl;
    }
  }
}
