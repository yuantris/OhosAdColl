import { expCompany, expInfo } from '../../entity/ExpBeans'

export class ExpressBean {
  id: number | null
  time: number | null
  company: expCompany
  info: expInfo

  constructor(company: expCompany, info: expInfo, id: number | null = null, time: number | null = null) {
    this.id = id
    this.time = time
    this.company = company
    this.info = info
  }
}