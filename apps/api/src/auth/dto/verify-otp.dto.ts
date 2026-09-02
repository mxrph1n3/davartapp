import { IsString, Length, Matches } from 'class-validator';

export class VerifyOtpDto {
  @IsString()
  @Matches(/^\+7\d{10}$/, {
    message: 'Phone must be in format +7XXXXXXXXXX',
  })
  phone!: string;

  @IsString()
  @Length(4, 4)
  @Matches(/^\d{4}$/, { message: 'Code must be 4 digits' })
  code!: string;
}
