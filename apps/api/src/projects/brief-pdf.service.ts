import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { Injectable } from '@nestjs/common';
import { ProjectStatus } from '@prisma/client';
import PDFDocument from 'pdfkit';
import {
  BRIEF_ATTACHMENTS,
  BRIEF_GENERAL_FIELDS,
  BRIEF_INTRO,
  BRIEF_ROOM_SECTIONS,
  formatBriefValue,
  formatRoomField,
  type BriefAnswers,
} from './brief-questionnaire';

interface BriefPdfData {
  projectName: string;
  address: string | null;
  style: string | null;
  budget: number | null;
  wishes: string | null;
  rooms: Array<{ name: string; type?: string; area?: number }>;
  answers?: BriefAnswers | null;
}

/** Built-in PDF fonts have no Cyrillic: the brief came out as gibberish. */
const FONT_DIR = join(process.cwd(), 'assets', 'fonts');
const FONT_REGULAR = join(FONT_DIR, 'DejaVuSans.ttf');

@Injectable()
export class BriefPdfService {
  async generate(data: BriefPdfData): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      const doc = new PDFDocument({ margin: 50 });
      if (existsSync(FONT_REGULAR)) {
        doc.registerFont('body', FONT_REGULAR);
        doc.font('body');
      }
      const chunks: Buffer[] = [];

      doc.on('data', (chunk: Buffer) => chunks.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      doc.fontSize(20).text('Анкета', { align: 'center' });
      doc.moveDown(0.5);
      doc.fontSize(10).text(BRIEF_INTRO);
      doc.moveDown();
      doc.fontSize(12).text(`Проект: ${data.projectName}`);
      if (data.address) doc.text(`Адрес проекта: ${data.address}`);
      doc.moveDown();

      const general = data.answers?.general ?? {};
      doc.fontSize(14).text('Общие вопросы');
      doc.moveDown(0.3);
      for (const field of BRIEF_GENERAL_FIELDS) {
        const value = formatBriefValue(field.id, general[field.id]);
        if (!value && field.id.endsWith('Note')) continue;
        doc.fontSize(10).fillColor('#444444').text(field.label);
        doc
          .fontSize(11)
          .fillColor('#000000')
          .text(value || '—');
        doc.moveDown(0.4);
      }

      const lifestyle = general.lifestyle?.trim();
      if (lifestyle && !general.routine?.trim() && !general.hobbies?.trim()) {
        doc
          .fontSize(10)
          .fillColor('#444444')
          .text('Личность, распорядок, хобби');
        doc.fontSize(11).fillColor('#000000').text(lifestyle);
        doc.moveDown(0.4);
      }

      doc.moveDown(0.4);
      doc.fontSize(14).text('Пожелания к помещениям');
      doc.moveDown(0.3);
      for (const section of BRIEF_ROOM_SECTIONS) {
        const room = data.answers?.rooms?.[section.id];
        const included = room?.included !== false;
        doc
          .fontSize(12)
          .text(`${section.title}${included ? '' : ' (нет в проекте)'}`);
        if (included) {
          for (const field of section.fields) {
            const value = formatRoomField(field, room);
            doc.fontSize(10).fillColor('#444444').text(field.label);
            doc
              .fontSize(11)
              .fillColor('#000000')
              .text(value || '—');
            doc.moveDown(0.3);
          }
        }
        doc.moveDown(0.4);
      }

      if (data.rooms.length > 0) {
        doc.fontSize(14).text('Другие помещения');
        data.rooms.forEach((room) => {
          const details = [
            room.name,
            room.type ? `тип: ${room.type}` : null,
            room.area ? `${room.area} м²` : null,
          ]
            .filter(Boolean)
            .join(', ');
          doc.fontSize(12).text(`• ${details}`);
        });
        doc.moveDown();
      }

      doc.fontSize(14).text('Вложения');
      BRIEF_ATTACHMENTS.forEach((item) => {
        doc.fontSize(11).text(`• ${item}`);
      });

      doc.end();
    });
  }
}

export const PROJECT_STATUS_LABELS: Record<ProjectStatus, string> = {
  brief_filling: 'Бриф',
  measurement: 'Замер',
  in_progress: 'Планировка',
  materials: 'Ведомость материалов и мебели',
  visualization: 'Визуализация',
  final_assembly: 'Итоговые чертежи и сборка проекта',
  completed: 'Завершен',
  archived: 'Архив',
};

/** Brief stays open through layout; locks after планировка. */
export const BRIEF_EDITABLE_STATUSES: ProjectStatus[] = [
  ProjectStatus.brief_filling,
  ProjectStatus.measurement,
  ProjectStatus.in_progress,
];
