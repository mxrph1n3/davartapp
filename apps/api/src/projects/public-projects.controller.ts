import { Controller, Get, Param } from '@nestjs/common';
import { ProjectIdParamDto } from './dto/projects.dto';
import { ProjectsService } from './projects.service';

/** Portfolio examples — readable without an account. */
@Controller('projects')
export class PublicProjectsController {
  constructor(private readonly projectsService: ProjectsService) {}

  @Get('showcase')
  showcase() {
    return this.projectsService.listShowcase();
  }

  @Get('showcase/:id')
  getShowcase(@Param() params: ProjectIdParamDto) {
    return this.projectsService.getShowcaseById(params.id);
  }
}
