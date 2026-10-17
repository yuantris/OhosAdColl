

export class expTtl {
  result: boolean;
  returnCode: string;
  orderTime: string;
  data: string[];
  toName: string;
  fromName: string;
  message: string;
  toNum: string;
  fromNum: string;

  constructor(result: boolean, returnCode: string, orderTime: string, data: string[], toName: string, fromName: string,
    message: string, toNum: string, fromNum: string) {
    this.result = result;
    this.returnCode = returnCode;
    this.orderTime = orderTime;
    this.data = data;
    this.toName = toName;
    this.fromName = fromName;
    this.message = message;
    this.toNum = toNum;
    this.fromNum = fromNum;
  }
}

export class expTimeData {
  com: string;  // 例如 "shentong"
  arrivalTime: string;  // 例如 "2024-09-04 15:00:00"
  mayExpendTime: string;  // 例如 "1天3小时"
  totalAvg: string;  // 例如 "0天21小时"
  totalAvgInt: number;  // 例如 21
  startTime: string;  // 例如 "2024-09-03 18:00:00"
  deliveryExpendTime2: string | null;  // 允许null值
  type: string;  // 例如 "10"
  deliveryExpendTime: string | null;  // 允许null值

  constructor(com: string, arrivalTime: string, mayExpendTime: string, totalAvg: string,
    totalAvgInt: number, startTime: string, deliveryExpendTime2: string, type: string, deliveryExpendTime: string) {
    this.arrivalTime = arrivalTime;
    this.com = com;
    this.deliveryExpendTime = deliveryExpendTime;
    this.deliveryExpendTime2 = deliveryExpendTime2;
    this.mayExpendTime = mayExpendTime;
    this.startTime = startTime;
    this.totalAvg = totalAvg;
    this.totalAvgInt = totalAvgInt;
    this.type = type;
  }
}