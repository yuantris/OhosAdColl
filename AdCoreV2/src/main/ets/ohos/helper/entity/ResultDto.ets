export class ResultDto {
  code: number | string;
  message: string | Resource;
  data: string | Object | ArrayBuffer | null;

  constructor() {
    this.code = 0;
    this.message = '';
    this.data = null;
  }
}