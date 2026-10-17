import { APIs } from '../common/zyhttp/APIs';
import { expCompany, expInfo, expNetwork, expPrice } from '../entity/ExpBeans';
import { expTtl } from '../common/zyhttp/Resp';
import { BarCodeResultBean } from '../common/entity/BarCodeBean';
import { fetchWithCache } from '@zycore/network';
import { Log } from '@zycore/common';


export function getCompanys(): Promise<expCompany[] | null> {
  return new Promise<expCompany[] | null>((resolve, reject) => {
    fetchWithCache(APIs.company[0], APIs.company[1], {}, 3600).then((resp) => {
      if (resp.code == 1) {
        resolve(resp.data as expCompany[])
      } else {
        reject(null)
      }
    }).catch((error: object) => {
      reject(error)
    })
  })
}

export function getExpInfo(params: ESObject = { oid: "", tel: "" }): Promise<expInfo | null> {
  return new Promise<expInfo | null>((resolve, reject) => {
    fetchWithCache(APIs.info[0], APIs.info[1], params, 60).then((resp) => {
      if (resp.code == 1) {
        Log.debug(`getExpInfo:${JSON.stringify(resp)}`)
        resolve(resp.data as expInfo)
      } else {
        reject(resp.message)
      }
    }).catch((error: object) => {
      reject(error)
    })
  })
}

export async function getExpPrice(params: ESObject = {
  com: "shentong",
  receive: "北京市朝阳区",
  send: "山东省济南市槐荫区",
  weight: 1
}): Promise<expPrice | null> {
  let resp = await fetchWithCache(APIs.price[0], APIs.price[1], params)
  Log.debug(`getExpPrice:${JSON.stringify(resp)}`)
  if (resp.code == 1) {
    return resp.data as expPrice
  }
  return null
}

export async function getExpNetwork(params: ESObject = {
  area: "山东-济南市-槐荫区",
  address: "恒大财富中心",
  offset: 0
}): Promise<expNetwork | null> {
  let resp = await fetchWithCache(APIs.network[0], APIs.network[1], params)
  Log.debug(`getExpNetwork:${JSON.stringify(resp)}`)
  if (resp.code == 1) {
    return resp.data as expNetwork
  }
  return null
}


export async function getExpTtl(params: ESObject = {
  companyList: "shentong",
  from: "广东深圳",
  to: "北京",
  orderTime: "2023-02-01 00:00:00"
}): Promise<expTtl | null> {
  let resp = await fetchWithCache(APIs.ttl[0], APIs.ttl[1], params)
  Log.debug(`params:${JSON.stringify(params)}`)
  Log.debug(`getExpTtl:${JSON.stringify(resp)}`)
  if (resp.code == 1) {
    return resp.data as expTtl
  }
  return null
}

//条码查询
export async function getBarCode(params: ESObject = {
  code: '11111',
  pageNum: 1,
  pageSize: 1
}): Promise<BarCodeResultBean | null> {
  let resp = await fetchWithCache(APIs.barcode[0], APIs.barcode[1], params)
  Log.debug(`params:${JSON.stringify(params)}`)
  Log.debug(`getBarCode:${JSON.stringify(resp)}`)
  if (resp.code == 1) {
    return resp.data as BarCodeResultBean
  }
  return null
}

