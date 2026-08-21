import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import * as Sentry from '@sentry/node';
import helmet from 'helmet';
import { AppModule } from './app.module';
import {
  resolveCorsOrigins,
  validateEnvironment,
} from './common/env.validation';

async function bootstrap() {
  validateEnvironment();

  const sentryDsn = process.env.SENTRY_DSN;
  if (sentryDsn) {
    Sentry.init({
      dsn: sentryDsn,
      environment: process.env.NODE_ENV ?? 'development',
      tracesSampleRate: 0.1,
    });
  }

  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  app.use(
    helmet({
      // CRM lives on another origin (:3001 / crm.*) and must read JSON.
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );
  app.setGlobalPrefix('api');

  const corsOrigin = resolveCorsOrigins();
  app.enableCors(
    corsOrigin === false
      ? { origin: false }
      : { origin: corsOrigin, credentials: true },
  );

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  const port = process.env.PORT ?? 3000;
  await app.listen(port);
}
bootstrap();
