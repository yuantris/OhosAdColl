import { TitleBar } from '../common/view/TitleBar'
import { CounterComponent, CounterType, router } from '@kit.ArkUI'
import { ExpressInfo } from '../common/entity/ExpressInfo'
import Constants from '../common/Constants'
import { getExpPrice, getExpTtl } from '../service/default'
import { SearchResult } from './SearchResultPage'
import { expCompany } from '../entity/ExpBeans'
import Util from '../common/util/Util'
import { DateUtils, Log, StrUtils } from '@zycore/common'

export class ExpressInfoSearchProps {
  index: number
  from: string
  to: string
  from_area_index: number[]
  to_area_index: number[]

  constructor(index: number = 0, area: number[] = [0, 0, 0], from: string, to: string) {
    this.index = index
    this.from_area_index = area
    this.to_area_index = area
    this.from = from
    this.to = to
  }
}

@Entry
@Component
struct ExpressInfoSearch {
  @State from: ExpressInfo = new ExpressInfo(100, '')
  @State info: ExpressInfoSearchProps = new ExpressInfoSearchProps(0, [0, 0, 0], '', '')
  @State defaultColor: string = '#666666'
  @State com: expCompany | null = null
  @State valueKg: number = 1
  @State selectedTime: Date = new Date()
  @State from_area_index: number[] = [0, 0, 0]
  @State to_area_index: number[] = [0, 0, 0]
  @State isRemove: boolean = false

  aboutToAppear(): void {
    if (router.getParams() as ExpressInfo) {
      this.from = router.getParams() as ExpressInfo
    }
  }

  onPageShow(): void {
    const params = router.getParams();
    Log.debug('onPageShow:', JSON.stringify(params));
    if (params === undefined) {
      return
    }
    if ((params as ExpressInfoSearchProps).from) {
      this.info = params as ExpressInfoSearchProps;
      if (this.info.from) {
        this.from_area_index = this.info.from_area_index
      }
      if (this.info.to) {
        this.to_area_index = this.info.to_area_index
      }
    } else if ((params as expCompany).cname) {
      this.com = params as expCompany;
    }

  }

  build() {
    RelativeContainer() {

      Column({ space: '10vp' }) {
        TitleBar({ title: this.from.type === 100 ? '快递价格查询' : '快递时效查询' })

        Column() {
          Row() {
            Image($r('app.media.exp_price_1'))
              .fitOriginalSize(true)

            Text(StrUtils.isNotBlank(this.info.from) ? this.info.from : '从哪里寄出')
              .fontSize(15)
              .fontColor(this.defaultColor)
              .margin({
                left: 15
              })

            Blank()

            Image($r('app.media.arrow_2'))
              .fitOriginalSize(true)
              .constraintSize({ minWidth: 8, minHeight: 8 })

          }
          .width('100%')
          .padding(20)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.info.index = 0
            this.info.from_area_index = this.from_area_index
            router.pushUrl({ url: "pages/AreaSelect", params: this.info })
          })

          Divider()

          Row() {
            Image($r('app.media.exp_price_2'))
              .fitOriginalSize(true)

            Text(StrUtils.isNotBlank(this.info.to) ? this.info.to : '要寄到哪里')
              .fontSize(15)
              .fontColor(this.defaultColor)
              .margin({
                left: 15
              })

            Blank()

            Image($r('app.media.arrow_2'))
              .fitOriginalSize(true)
              .constraintSize({ minWidth: 8, minHeight: 8 })

          }
          .width('100%')
          .padding(20)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.info.index = 1
            this.info.to_area_index = this.to_area_index
            router.pushUrl({ url: "pages/AreaSelect", params: this.info })
          })

        }.width('93%')
        .backgroundColor(Color.White)
        .borderRadius(15)

        Column() {
          Row() {

            Text('物流选择')
              .fontSize(15)
              .fontColor('#333333')
              .margin({
                left: 15
              })

            Blank()

            Text(this.com?.cname)
              .fontSize(12)
              .fontColor('#666666')
              .margin({ right: 10 })

            Image($r('app.media.arrow_2'))
              .fitOriginalSize(true)
              .constraintSize({ minWidth: 8, minHeight: 8 })

          }
          .width('100%')
          .padding(20)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            // router.pushUrl({
            //   url: "pages/CompanyPicker",
            //   params: {
            //     info: '',
            //     from: 'express'
            //   }
            // })
            // ActionUtils.showActionSheet({
            //   sheets: ["顺丰", "京东", "德邦", "圆通", "中通", "申通", "韵达", "EMS"],
            //   clickCallBack: (data: string) => {
            //     switch (data) {
            //       case '顺丰':
            //         this.com = new expCompany('顺丰', 'shunfeng', null)
            //         break
            //       case '京东':
            //         this.com = new expCompany('京东', 'jd', null)
            //         break
            //       case '德邦':
            //         this.com = new expCompany('德邦快递', 'debangkuaidi', null)
            //         break
            //       case '圆通':
            //         this.com = new expCompany('圆通', 'yuantong', null)
            //         break
            //       case '中通':
            //         this.com = new expCompany('中通', 'zhongtong', null)
            //         break
            //       case '申通':
            //         this.com = new expCompany('申通', 'shentong', null)
            //         break
            //       case '韵达':
            //         this.com = new expCompany('韵达', 'yunda', null)
            //         break
            //       case 'EMS':
            //         this.com = new expCompany('EMS', 'ems', null)
            //         break
            //     }
            //   }
            // });
          })

          Divider()

          Row() {

            Text('下单时间')
              .fontSize(15)
              .fontColor('#333333')
              .margin({
                left: 15
              })

            Blank()

            Text(DateUtils.getFormatDateStr(this.selectedTime))
              .fontSize(12)
              .fontColor('#666666')
              .margin({ right: 10 })
            Image($r('app.media.arrow_2'))
              .fitOriginalSize(true)
              .constraintSize({ minWidth: 8, minHeight: 8 })

          }
          .width('100%')
          .padding(20)
          .visibility(this.from.type === 100 ? Visibility.None : Visibility.Visible)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            DatePickerDialog.show({
              start: new Date("1900-1-31"),
              end: new Date("2100-12-31"),
              selected: this.selectedTime,
              showTime: true,
              useMilitaryTime: true,
              alignment: DialogAlignment.Bottom,
              disappearTextStyle: { color: '#999999', font: { size: '22fp', weight: FontWeight.Normal } },
              textStyle: { color: '#666666', font: { size: '18fp', weight: FontWeight.Regular } },
              selectedTextStyle: { color: '#333333', font: { size: '14fp', weight: FontWeight.Bold } },
              onDateAccept: (value: Date) => {
                // 通过Date的setFullYear方法设置按下确定按钮时的日期，这样当弹窗再次弹出时显示选中的是上一次确定的日期
                this.selectedTime = value
                console.info("DatePickerDialog:onDateAccept()" + value.toString())
              },
              onCancel: () => {
                console.info("DatePickerDialog:onCancel()")
              },
              onDateChange: (value: Date) => {
                console.info("DatePickerDialog:onDateChange()" + value.toString())
              },
              onDidAppear: () => {
                console.info("DatePickerDialog:onDidAppear()")
              },
              onDidDisappear: () => {
                console.info("DatePickerDialog:onDidDisappear()")
              },
              onWillAppear: () => {
                console.info("DatePickerDialog:onWillAppear()")
              },
              onWillDisappear: () => {
                console.info("DatePickerDialog:onWillDisappear()")
              }
            })
          })

          Row() {
            Text('预估重量')
              .fontSize(15)
              .fontColor('#333333')
              .margin({
                left: 15
              })

            Blank()

            CounterComponent({
              options: {
                type: CounterType.COMPACT,
                numberOptions: {
                  label: "KG",
                  min: 0,
                  value: this.valueKg,
                  max: 10000
                }
              }
            })


          }
          .width('100%')
          .padding(20)
          .visibility(this.from.type === 100 ? Visibility.Visible : Visibility.None)
          .alignItems(VerticalAlign.Center)

        }.width('93%')
        .backgroundColor(Color.White)
        .borderRadius(15)

        // AdLayout({
        //   adId: AD.CSJ_INFO_NATIVE_ID,
        //   adName: 'express_info_check',
        //   adType: AdType.NATIVE,
        // })


      }.width('100%')

      Button('查询', { type: ButtonType.Normal, stateEffect: true })
        .borderRadius(8)
        .backgroundColor(0x317aff)
        .alignRules({
          bottom: {
            anchor: '__container__', align: VerticalAlign.Bottom
          },
          middle: { anchor: '__container__', align: HorizontalAlign.Center }
        })
        .margin({
          bottom: 40
        })
        .width('93%')
        .height(50)
        .onClick(() => {

          Log.debug('已点击查询按钮')
          const regex = /[\[\]",\s]/g
          let cleanedFrom = this.info.from.replace(regex, '');
          let cleanedTo = this.info.to.replace(regex, '');

          Log.debug(`查询地区 data : ${cleanedFrom}--->${cleanedTo}`)
          switch (this.from.type) {
            case Constants.TYPE_PRICE:
              Log.debug('正在查询价格：' + cleanedFrom + '--->' + cleanedTo)

              getExpPrice({
                com: this.com?.ccode,
                receive: cleanedTo,
                send: cleanedFrom,
                weight: this.valueKg
              }).then((value) => {

                if (!this.com?.ccode) {
                  Util.toast('无快递产品或该地未开通查询业务')
                  return
                }
                if (!value) {
                  Util.toast('此快递公司暂时无查询数据')
                  return
                }

                Log.debug(`数据 ：${JSON.stringify(value)}`)
                const response: ExpressResponse = JSON.parse(JSON.stringify(value))
                const price: number = response.data.combos[0].price
                router.pushUrl({
                  url: "pages/SearchResultPage",
                  params: new SearchResult('预估基础运费', String(price))
                });


              })
              break
            case Constants.TYPE_TIME:
              Log.debug('正在查询时效：' + cleanedFrom + '--->' + cleanedTo)

              getExpTtl({
                companyList: this.com?.ccode,
                from: cleanedFrom,
                to: cleanedTo,
                orderTime: DateUtils.getFormatDateStr(this.selectedTime),
              }).then((value) => {
                Log.debug(`数据 ：${JSON.stringify(value)}`)
                if (value = null) {
                  Util.toast('未查询到相关时效信息，请稍后重试')
                  return
                }

                if (!cleanedFrom || !cleanedTo) {
                  Util.toast('未填写相关信息')
                  return
                }

                const regex = /"mayExpendTime":"([^"]+)"/;
                const match = JSON.stringify(value).match(regex);

                if (match) {
                  const mayExpendTimeValue = match[1];
                  router.pushUrl({
                    url: "pages/SearchResultPage",
                    params: new SearchResult('预估时效', String(mayExpendTimeValue))
                  });
                } else {
                  Log.error("未找到 mayExpendTime 的值");
                  Util.toast('未查询到相关时效信息，请稍后重试')
                }

              })
              break
          }
        })
    }.width('100%')
    .height('100%')
    .backgroundColor('#f6f4f5')
  }
}

interface Combo {
  price: number;
  productName: string;
}

interface GeneratedTypeLiteralInterface {
  com: string;
  combos: Combo[];
}

interface ExpressResponse {
  data: GeneratedTypeLiteralInterface;
  message: string;
  status: string;
}