export default class V4 {
  csj: V4Config;
  it: string;
  tx: V4Config;
  hw: V4Config;

  constructor() {
    this.csj = new V4Config();
    this.it = '';
    this.tx = new V4Config();
    this.hw = new V4Config();
  }
}

export class V4Config {
  appid: string
  info: string
  left_info: string
  open: string
  lscr: string
  video: string

  constructor() {
    this.appid = '';
    this.info = '';
    this.left_info = '';
    this.open = '';
    this.lscr = '';
    this.video = '';
  }
}