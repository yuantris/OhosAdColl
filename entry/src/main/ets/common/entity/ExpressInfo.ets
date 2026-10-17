
export class ExpressInfo {
  public type: number
  public id: ResourceStr

  constructor(type: number, id: ResourceStr) {
    this.id = id
    this.type = type
  }

}