import { ExecutionContext, Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/** Lets guests through; when a valid token is sent, `request.user` is filled. */
@Injectable()
export class OptionalJwtAuthGuard extends AuthGuard('jwt') {
  async canActivate(context: ExecutionContext): Promise<boolean> {
    try {
      await super.canActivate(context);
    } catch {
      // No or expired token — continue as a guest.
    }
    return true;
  }

  handleRequest<TUser>(_err: unknown, user: TUser): TUser {
    return user;
  }
}
