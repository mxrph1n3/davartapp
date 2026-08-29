import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  Param,
  Post,
  Put,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { JwtPayload } from '../auth/decorators/current-user.decorator';
import { assertAdminAccess } from '../common/admin-access';
import { assertDevEndpointsAllowed } from '../common/dev-endpoints';
import {
  ProjectIdParamDto,
  ProjectMemberUserParamDto,
  CreateProjectDto,
  InviteProjectMemberDto,
  UpdateBriefDto,
} from './dto/projects.dto';
import { ProjectsService } from './projects.service';

@Controller('projects')
@UseGuards(JwtAuthGuard)
export class ProjectsController {
  constructor(private readonly projectsService: ProjectsService) {}

  @Get()
  list(@CurrentUser() user: JwtPayload) {
    return this.projectsService.listForUser(user.sub);
  }

  @Post()
  create(@CurrentUser() user: JwtPayload, @Body() dto: CreateProjectDto) {
    return this.projectsService.create(user.sub, dto);
  }

  @Delete(':id')
  @HttpCode(200)
  delete(
    @CurrentUser() user: JwtPayload,
    @Param() params: ProjectIdParamDto,
  ) {
    return this.projectsService.delete(user.sub, params.id);
  }

  @Post('seed-demo')
  @HttpCode(200)
  seedDemo(@CurrentUser() user: JwtPayload) {
    assertDevEndpointsAllowed();
    return this.projectsService.seedDemoProjects(user.sub);
  }

  @Get(':id')
  getById(@CurrentUser() user: JwtPayload, @Param() params: ProjectIdParamDto) {
    return this.projectsService.getById(user.sub, params.id);
  }

  @Get(':id/members')
  listMembers(
    @CurrentUser() user: JwtPayload,
    @Param() params: ProjectIdParamDto,
  ) {
    return this.projectsService.listMembers(
      user.sub,
      params.id,
      user.role,
      user.extraRoles ?? [],
    );
  }

  @Post(':id/members')
  inviteMember(
    @CurrentUser() user: JwtPayload,
    @Param() params: ProjectIdParamDto,
    @Body() dto: InviteProjectMemberDto,
  ) {
    return this.projectsService.inviteMember(
      user.sub,
      params.id,
      user.role,
      dto,
    );
  }

  @Delete(':id/members/:userId')
  removeMember(
    @CurrentUser() user: JwtPayload,
    @Param() params: ProjectMemberUserParamDto,
  ) {
    return this.projectsService.removeMember(
      user.sub,
      params.id,
      user.role,
      params.userId,
    );
  }

  @Get(':id/brief')
  getBrief(@CurrentUser() user: JwtPayload, @Param() params: ProjectIdParamDto) {
    return this.projectsService.getBrief(user.sub, params.id);
  }

  @Put(':id/brief')
  updateBrief(
    @CurrentUser() user: JwtPayload,
    @Param() params: ProjectIdParamDto,
    @Body() dto: UpdateBriefDto,
  ) {
    return this.projectsService.updateBrief(user.sub, params.id, dto);
  }

  @Get(':id/brief/pdf')
  async downloadBriefPdf(
    @CurrentUser() user: JwtPayload,
    @Param() params: ProjectIdParamDto,
    @Res() res: Response,
  ) {
    const pdf = await this.projectsService.generateBriefPdf(
      user.sub,
      params.id,
    );

    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="brief-${params.id}.pdf"`,
    });
    res.send(pdf);
  }

  @Post(':id/request-surveyor')
  @HttpCode(200)
  requestSurveyor(
    @CurrentUser() user: JwtPayload,
    @Param() params: ProjectIdParamDto,
  ) {
    return this.projectsService.requestSurveyor(user.sub, params.id);
  }

  @Post(':id/start-work')
  @HttpCode(200)
  startWork(
    @Param() params: ProjectIdParamDto,
    @Headers('x-admin-secret') adminSecret?: string,
  ) {
    assertAdminAccess(adminSecret);
    return this.projectsService.startWork(params.id);
  }
}
