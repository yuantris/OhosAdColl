export class InfoBean {
  ads?: Ads
}

export class Ads {
  csj?: Csj
}

export class Csj {
  appId?: string
  ban?: string
  info?: string
  info_left?: string
  lscr?: string
  modules?: Modules[]
}

export class Modules {
  ban?: Ad[]
  info?: Ad[]
  info_left?: Ad[]
  itemSize?: number
  lscr?: Ad[]
  moduleId?: string
  name?: string
  video?: Ad[]
}

export class Ad {
  adId?: string
  id?: string
  name?: string
}