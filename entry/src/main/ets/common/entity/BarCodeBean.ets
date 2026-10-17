export class BarCodeBean {
  name: string
  price: number

  constructor(name: string, price: number) {
    this.name = name
    this.price = price
  }
}
@Observed
export class BarCodeResultBean {
  pageNum?: number
  pageSize?: number
  total?: number
  pages?: number
  data?: dataModel
  list?: Array<listModel>
  constructor(pageNum?: number, pageSize?: number, total?: number,pages?: number,data?: dataModel, list?: Array<listModel>) {
    this.pageNum=pageNum
    this.pageSize=pageSize
    this.total=total
    this.pages=pages
    this.data=data
    this.list=list
  }

}

@Observed
export  class  listModel{
  categoryId:number
  title:string
  zkFinalPrice:string
  pictUrl:string
  clickUrl:string
  constructor(categoryId:number,title:string, zkFinalPrice:string, pictUrl:string,clickUrl:string) {
    this.categoryId=categoryId
    this.title=title
    this.zkFinalPrice=zkFinalPrice
    this.pictUrl=pictUrl
    this.clickUrl=clickUrl
  }
}
@Observed
export  class  dataModel{
  goodsName:string
  img:string
  price:string
  constructor(goodsName:string,img:string,price:string) {
    this.goodsName=goodsName
    this.img=img
    this.price=price
  }
}
