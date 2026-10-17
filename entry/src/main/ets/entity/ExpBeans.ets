/**
 * 快递查询返回信息
 */
export class expInfo {
  /**
   *  错误返回码
   */
  returnCode: number | string;
  /**
   * 单号
   */
  nu: number | string;
  /**
   *快递公司编码,小写字母
   */
  com: number | string;
  /**
   *快递单当前状态，包括0在途，1揽收，2疑难，3签收，4退签，5派件，6退回，7转单，10待清关，11清关中，12已清关，13清关异常，14拒签等36个状态
   */
  state: number | string;
  /**
   *消息体
   */
  message: string | Resource;
  /**
   *最新查询结果，数组，包含多项，全量，倒序（即时间最新的在最前），每项都是对象，对象包含字段请展开
   */
  data: timeLine[];

  constructor(returnCode: number | string, nu: number | string, com: number | string, state: number | string,
    message: string | Resource, data: timeLine[]) {
    this.returnCode = returnCode;
    this.nu = nu;
    this.com = com;
    this.state = state;
    this.message = message;
    this.data = data;
  }
}

/**
 * 快递查询：时间线信息
 */
export class timeLine {
  /**
   *  快递实时信息体
   * 【济南市】 您的快递已送货上门，签收人为【家门口】。如有疑问请联系
   */
  context: number | string;
  /**
   * 时间点
   */
  time: number | string;

  status: number | string;

  constructor(context: number | string, time: number | string, status: number | string) {
    this.context = context;
    this.time = time;
    this.status=status;
  }
}

/**
 * 快递：公司信息
 */
export class expCompany {
  /**
   *  公司名称
   *
   */
  cname: string | null;
  /**
   * 公司代码
   */
  ccode: string | null;
  /**
   * 公司图标
   */
  logo: string | null;

  constructor(cname: string | null, ccode: string | null, logo: string | null) {
    this.cname = cname;
    this.ccode = ccode;
    this.logo = logo;
  }
}


/**
 * 快递：价格信息
 */
export class expPrice {
  /**
   *  快递公司代码
   *
   */
  com: string | null;
  /**
   * 快递价格列表
   */
  combos: priceCombo[] | null;

  constructor(com: string | null, combos: priceCombo[] | null) {
    this.com = com;
    this.combos = combos;
  }
}

/**
 * 快递价格信息
 */
class priceCombo {
  /**
   *  快递价格
   *
   */
  price: string | number;
  /**
   * 快递类型
   */
  productName: string | null;

  constructor(price: string | number, productName: string | null) {
    this.price = price;
    this.productName = productName;
  }
}


class SubTel {
  complainTel: string;
  serviceTel: string;
  queryTel: string;
  remainSMS: string;
  kDNET_970562: string;

  constructor(complainTel: string, serviceTel: string, queryTel: string, remainSMS: string, kDNET_970562: string) {
    this.complainTel = complainTel;
    this.serviceTel = serviceTel;
    this.queryTel = queryTel;
    this.remainSMS = remainSMS;
    this.kDNET_970562 = kDNET_970562;
  }
}

export class NetList {
  companyName: string;
  latitude: number;
  netUsers: string[];
  remark: string;
  snatch: boolean;
  source: string;
  type: string;
  got: boolean;
  number: string;
  refuseArea: string;
  score: number;
  companyNumber: string;
  audit: boolean;
  xzqNumber: string;
  lock: number;
  tel: string;
  id: number;
  fax: string | null;
  xzqFullName: string;
  longitude: number;
  qq: string;
  subTel: SubTel;
  address: string;
  visible: boolean;
  lastModify: string;
  detailText: string;
  mobile: string;
  index: number;
  linkman: string;
  url: string;
  sId: string;
  companyId: number;
  workArea: string;
  name: string;
  telOne: string;
  md5Code: string;

  constructor(companyName: string, latitude: number, netUsers: string[], remark: string, snatch: boolean,
    source: string,
    type: string, got: boolean, number: string, refuseArea: string, score: number, companyNumber: string,
    audit: boolean, xzqNumber: string, lock: number, tel: string, id: number, fax: string | null, xzqFullName: string,
    longitude: number, qq: string, subTel: SubTel, address: string, visible: boolean, lastModify: string,
    detailText: string, mobile: string, index: number, linkman: string, url: string, sId: string, companyId: number,
    workArea: string, name: string, telOne: string, md5Code: string) {
    this.companyName = companyName;
    this.latitude = latitude;
    this.netUsers = netUsers;
    this.remark = remark;
    this.snatch = snatch;
    this.source = source;
    this.type = type;
    this.got = got;
    this.number = number;
    this.refuseArea = refuseArea;
    this.score = score;
    this.companyNumber = companyNumber;
    this.audit = audit;
    this.xzqNumber = xzqNumber;
    this.lock = lock;
    this.tel = tel;
    this.id = id;
    this.fax = fax;
    this.xzqFullName = xzqFullName;
    this.longitude = longitude;
    this.qq = qq;
    this.subTel = subTel;
    this.address = address;
    this.visible = visible;
    this.lastModify = lastModify;
    this.detailText = detailText;
    this.mobile = mobile;
    this.index = index;
    this.linkman = linkman;
    this.url = url;
    this.sId = sId;
    this.companyId = companyId;
    this.workArea = workArea;
    this.name = name;
    this.telOne = telOne;
    this.md5Code = md5Code;
  }
}

class CompanyTotal {
  companyId: number;
  companyNumber: string;
  companyName: string;
  count: number;

  constructor(companyId: number, companyNumber: string, companyName: string, count: number) {
    this.companyId = companyId;
    this.companyNumber = companyNumber;
    this.companyName = companyName;
    this.count = count;
  }
}

export class expNetwork {
  total: number;
  netList: NetList[];
  companyTotal: CompanyTotal[];
  message: string;
  status: number;

  constructor(total: number, netList: NetList[], companyTotal: CompanyTotal[], message: string, status: number) {
    this.total = total;
    this.netList = netList;
    this.companyTotal = companyTotal;
    this.message = message;
    this.status = status;
  }
}

