import { Controller, Get, Param, Res } from '@nestjs/common';
import type { Response } from 'express';
import { SkipThrottle } from '@nestjs/throttler';
import { TelegramService } from './telegram.service';

@SkipThrottle()
@Controller('open')
export class OpenAppController {
  constructor(private readonly telegram: TelegramService) {}

  @Get('orders/:clientId/:orderId')
  openOrder(
    @Param('clientId') clientId: string,
    @Param('orderId') orderId: string,
    @Res() res: Response,
  ) {
    const appUrl = this.telegram.orderAppUrl(clientId, orderId);
    res.type('html').send(`<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Davart — заказ</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 0;
      min-height: 100vh; display: grid; place-items: center; background: #111; color: #fff; }
    a { display: inline-block; background: #f5c518; color: #111; text-decoration: none;
      font-weight: 700; padding: 14px 24px; border-radius: 12px; }
    p { color: #aaa; }
  </style>
</head>
<body>
  <main>
    <p>Открыть заказ в приложении Davart</p>
    <p><a href="${appUrl}">Открыть заказ</a></p>
  </main>
</body>
</html>`);
  }
}
