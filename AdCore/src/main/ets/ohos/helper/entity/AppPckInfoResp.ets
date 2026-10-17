export interface Module{
  moduleId: string;
  name: string;
  ban: ModuleItem[];
  lscr: ModuleItem[];
  info: ModuleItem[];
  info_left: ModuleItem[];
  video: ModuleItem[];
}

export interface ModuleItem{
  adId: string;
  name: string;
  id: string;
}