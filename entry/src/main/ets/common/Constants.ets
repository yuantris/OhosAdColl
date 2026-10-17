export default class Constants {
  //全部快递
  static readonly TYPE_ALL = 0
  //运输中
  static readonly TYPE_TRAN = 1
  //派送中
  static readonly TYPE_SENDING = 2
  //待取件
  static readonly TYPE_WAIT = 3
  //已签收
  static readonly TYPE_SIGN = 4
  //退回中
  static readonly TYPE_BACK = 5
  //历史快递
  static readonly TYPE_HISTORY = 6
  //价格查询
  static readonly TYPE_PRICE = 100
  //时效查询
  static readonly TYPE_TIME = 101
  //快递网点查询
  static readonly TYPE_AREA = 102
  //条码查询
  static readonly TYPE_BARCODE = 103
  // 快递公司 kEY
  static readonly COMPANY = 'Company_express'

  static getTypeTitle(type: number): string {
    switch (type) {
      case Constants.TYPE_ALL:
        return '全部快递'
      case Constants.TYPE_TRAN:
        return '运输中'
      case Constants.TYPE_SENDING:
        return '派送中'
      case Constants.TYPE_WAIT:
        return '待取件'
      case Constants.TYPE_SIGN:
        return '已签收'
      case Constants.TYPE_BACK:
        return '退回中'
      case Constants.TYPE_HISTORY:
        return '历史快递'
      case Constants.TYPE_PRICE:
        return '快递价格查询'
      case Constants.TYPE_TIME:
        return '快递时效查询'
      case Constants.TYPE_AREA:
        return '快递网点查询'
      case Constants.TYPE_BARCODE:
        return '条码查询'
    }
    return ''
  }
}