import { ForbiddenException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';
import { ChatGateway } from '../src/chat/chat.gateway';
import { ChatService } from '../src/chat/chat.service';
import { PrismaService } from '../src/prisma/prisma.service';

describe('ChatGateway join ACL (e2e)', () => {
  let gateway: ChatGateway;
  const assertParticipant = jest.fn();

  beforeEach(async () => {
    assertParticipant.mockReset();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ChatGateway,
        {
          provide: JwtService,
          useValue: { verify: jest.fn() },
        },
        {
          provide: ChatService,
          useValue: { assertParticipant },
        },
        // Only used on connect (user lookup); join goes through ChatService.
        { provide: PrismaService, useValue: {} },
      ],
    }).compile();

    gateway = module.get(ChatGateway);
  });

  function makeClient() {
    return {
      data: { user: { sub: 'user-1', phone: '+79001234567' } },
      join: jest.fn(),
      emit: jest.fn(),
    };
  }

  it('allows join for chat participants', async () => {
    assertParticipant.mockResolvedValue({ chatId: 'chat-1', userId: 'user-1' });
    const client = makeClient();

    await gateway.handleJoin(client as never, 'chat-1');

    expect(assertParticipant).toHaveBeenCalledWith('user-1', 'chat-1');
    expect(client.join).toHaveBeenCalledWith('chat:chat-1');
    expect(client.emit).not.toHaveBeenCalled();
  });

  it('rejects join for non-participants', async () => {
    assertParticipant.mockRejectedValue(
      new ForbiddenException('Access denied'),
    );
    const client = makeClient();

    await gateway.handleJoin(client as never, 'chat-foreign');

    expect(client.join).not.toHaveBeenCalled();
    expect(client.emit).toHaveBeenCalledWith('error', {
      message: 'Access denied',
    });
  });
});
