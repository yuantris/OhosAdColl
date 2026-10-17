import { relationalStore, ValuesBucket } from '@kit.ArkData';
import { JSON } from '@kit.ArkTS';
import { ExpressBean } from '../entity/ExpressBean';
import { expCompany, expInfo, timeLine } from '../../entity/ExpBeans';
import Constants from '../Constants';

export default class RdbManager {
  private static rdbStore: relationalStore.RdbStore
  //遥控信息
  private static readonly TABLE_EXPRESS = "ExpressDB"
  private static readonly SQL_CREATE_TABLE_EXPRESS_DB =
    'CREATE TABLE IF NOT EXISTS ExpressDB (id INTEGER PRIMARY KEY AUTOINCREMENT,' +
      ' time INTEGER,' +
      ' company TEXT,' +
      ' nu TEXT,' +
      ' com TEXT,' +
      ' state LONG,' +
      ' data TEXT' +
      ')';

  static async init(context: Context) {
    const STORE_CONFIG: relationalStore.StoreConfig = {
      name: 'Express.db', // 数据库文件名
      securityLevel: relationalStore.SecurityLevel.S1, // 数据库安全级别
    };

    try {
      const store = await relationalStore.getRdbStore(context, STORE_CONFIG);
      console.info('Succeeded in getting RdbStore.');
      RdbManager.rdbStore = store;

      try {
        await store.executeSql(RdbManager.SQL_CREATE_TABLE_EXPRESS_DB);
      } catch (error) {
        console.error('Failed to execute SQL:', error);
      }

    } catch (err) {
      console.error(`Failed to get RdbStore. Code:${err.code}, message:${err.message}`);
    }
  }


  static insertOrUpdateExpressBean(expressBean: ExpressBean): Promise<number> {
    return new Promise<number>((resolve, reject) => {
      let predicates = new relationalStore.RdbPredicates(RdbManager.TABLE_EXPRESS)
      predicates.equalTo('nu', expressBean.info.nu)
      RdbManager.rdbStore.query(predicates).then((result) => {
        if (result.goToNextRow()) {
          let id = result.getLong(0)
          let predicates = new relationalStore.RdbPredicates(RdbManager.TABLE_EXPRESS)
          predicates.equalTo('id', id)
          let value: ValuesBucket = {
            'id': id,
            'time': new Date().getTime(),
            'company': JSON.stringify(expressBean.company),
            'nu': expressBean.info.nu,
            'com': expressBean.info.com,
            'state': expressBean.info.state,
            'data': JSON.stringify(expressBean.info.data)
          }

          RdbManager.rdbStore.update(value, predicates).then(result => resolve(result))
            .catch((error: object) => reject(error))

        } else {
          let value: ValuesBucket = {
            'id': null,
            'time': new Date().getTime(),
            'company': JSON.stringify(expressBean.company),
            'nu': expressBean.info.nu,
            'com': expressBean.info.com,
            'state': expressBean.info.state,
            'data': JSON.stringify(expressBean.info.data)
          }
          RdbManager.rdbStore.insert(RdbManager.TABLE_EXPRESS, value).then(result => {
            resolve(result)
          })
            .catch((error: object) => {
              reject(error)
            })
        }
      }).catch((error: object) => {
        reject(error)
      })
    })
  }

  static updateExpressBean(nu: string, expInfo: expInfo): Promise<number> {
    return new Promise<number>((resolve, reject) => {
      let predicates = new relationalStore.RdbPredicates(RdbManager.TABLE_EXPRESS)
      predicates.equalTo('nu', nu)

      RdbManager.rdbStore.query(predicates).then((result) => {
        if (result.goToNextRow()) {
          let id = result.getLong(0)
          let predicates = new relationalStore.RdbPredicates(RdbManager.TABLE_EXPRESS)
          predicates.equalTo('id', id)
          let value: ValuesBucket = {
            'data': JSON.stringify(expInfo.data)
          }
          RdbManager.rdbStore.update(value, predicates).then(result => resolve(result))
            .catch((error: object) => reject(error))

        }
      }).catch((error: object) => {
        reject(error)
      })
    })
  }

  static delExpressBean(expressBean: ExpressBean): Promise<number> {
    return new Promise<number>((resolve, reject) => {
      let predicates = new relationalStore.RdbPredicates(RdbManager.TABLE_EXPRESS)
      predicates.equalTo('nu', expressBean.info.nu)
      RdbManager.rdbStore.delete(predicates)
        .then(result => resolve(result))
        .catch((error: object) => reject(error))
    })
  }

  static delExpressBeanForId(id: string | number): Promise<number> {
    return new Promise<number>((resolve, reject) => {
      let predicates = new relationalStore.RdbPredicates(RdbManager.TABLE_EXPRESS)
      predicates.equalTo('nu', id)
      RdbManager.rdbStore.delete(predicates)
        .then(result => resolve(result))
        .catch((error: object) => reject(error))
    })
  }

  // 包括 1.揽收 0.在途 5.派件 3.签收 6.退回 4.退签 7.转投 2.疑难 8.清关 14.拒签    10个简单状态
  // 1 0 5 3 6 4 7 2 8 14
  static queryExpressBeans(type: number): Promise<Array<ExpressBean>> {
    let predicates = new relationalStore.RdbPredicates(RdbManager.TABLE_EXPRESS)
    switch (type) {
      case Constants.TYPE_ALL: //全部快递
        break
      case Constants.TYPE_TRAN: //运输中
        predicates.in('state', [1, 0, 7, 2, 8])
        break
      case Constants.TYPE_SENDING: //派送中
        predicates.in('state', [5])
        break
      case Constants.TYPE_WAIT: //待取件
        predicates.in('state', [5])
        break
      case Constants.TYPE_SIGN: //已签收
        predicates.in('state', [3])
        break
      case Constants.TYPE_BACK: //退回中
        predicates.in('state', [6, 4, 14])
        break
      case Constants.TYPE_HISTORY: //历史快递
        predicates.in('state', [3, 6, 4, 14])
        break
      case Constants.TYPE_TRAN:
        predicates.in('state', ['0', '1', '2', '5', '7', '10', '11', '12', '13'])
        break
      case Constants.TYPE_SENDING:
        predicates.in('state', ['5'])
        break
      case Constants.TYPE_BACK:
        predicates.in('state', ['4', '7', '14'])
        break
    }
    return new Promise<Array<ExpressBean>>((resolve, reject) => {
      RdbManager.rdbStore.query(predicates).then((result) => {
        let expressBeans: Array<ExpressBean> = Array<ExpressBean>()
        while (result.goToNextRow()) {
          let expressBean = new ExpressBean(
            JSON.parse(result.getString(2)) as expCompany,
            new expInfo('', result.getString(3), result.getString(4), result.getLong(5), '',
              JSON.parse(result.getString(6)) as timeLine[]), result.getLong(0), result.getLong(1))
          expressBeans.push(expressBean)
        }
        resolve(expressBeans)
      }).catch((error: object) => {
        reject(error)
      })
    })
  }
}