-- Expand project lifecycle stages.
ALTER TYPE "ProjectStatus" ADD VALUE 'measurement';
ALTER TYPE "ProjectStatus" ADD VALUE 'materials';
ALTER TYPE "ProjectStatus" ADD VALUE 'visualization';
ALTER TYPE "ProjectStatus" ADD VALUE 'final_assembly';
