import { TitleBar } from '../common/view/TitleBar';
import { expCompany, expInfo, timeLine } from '../entity/ExpBeans';
import { router } from '@kit.ArkUI';
import { getCompanys, getExpInfo } from '../service/default';
import RdbManager from '../common/zyhttp/RdbManager';
import { ExpressBean } from '../common/entity/ExpressBean';
import View from '../common/View';
import Util from '../common/util/Util';
import Preference from '../common/util/Preference';
import { Log, StrUtils } from '@zycore/common';


async function putData(company: expCompany | null, info: expInfo): Promise<number> {
  if (company == null) {
    const coms = await getCompanys();
    if (coms != null) {
      for (let i = coms.length - 1; i >= 0; i--) {
        if (coms[i].ccode == info.com) {
          company = coms[i];
          break;
        }
      }
    }
  }

  if (company != null) {
    await RdbManager.insertOrUpdateExpressBean(new ExpressBean(company, info));
  }

  return Promise.reject(info.nu);
}


@Entry
@Component
struct ExpressResult {
  data: ExpressResultModel = router.getParams() as ExpressResultModel
  @State company: expCompany | null = this.data.company
  @State info: expInfo = this.data.info
  @State beannu: string | number = this.data.info.nu

  onPageShow(): void {
    let nu: string | number = this.info.nu

    Preference.getData(nu as string).then((phone) => {
      getExpInfo(StrUtils.isBlank(phone) ? { oid: nu } : { oid: nu, tel: phone })
        .then(info => {
          if (info) {
            RdbManager.updateExpressBean(nu as string, info as expInfo)
            putData(this.company, this.info).then((nu) => {
              this.beannu = nu
            })
          }
        })
    })


  }

  build() {
    RelativeContainer() {
      Image($r('app.media.express_check_express_info_title_bg'))
        .width('100%')
      TitleBar({
        title: '快递详情'
      }).id('title_bar')

      Column({ space: 16 }) {
        RelativeContainer() {
          Image(this.company?.logo || $r('app.media.express_default'))
            .width(60)
            .borderRadius(12)
            .objectFit(ImageFit.Contain)
            .alignRules({
              top: { anchor: View.container, align: VerticalAlign.Top },
              bottom: { anchor: View.container, align: VerticalAlign.Bottom },
            })
            .id('head')

          Text(this.company?.cname || '未知快递')
            .id('ex_name')
            .fontSize(14)
            .margin({ left: 10 })
            .alignRules(
              {
                'top': { 'anchor': 'head', 'align': VerticalAlign.Top },
                'bottom': { 'anchor': 'ex_num', 'align': VerticalAlign.Top },
                'left': { 'anchor': 'head', 'align': HorizontalAlign.End }
              }
            )

          Text(this.info.nu + '')
            .id('ex_num')
            .fontSize(14)
            .fontColor(Color.Gray)
            .copyOption(CopyOptions.InApp)
            .margin({ left: 10, bottom: 10 })
            .alignRules(
              {
                'bottom': { 'anchor': 'head', 'align': VerticalAlign.Bottom },
                'left': { 'anchor': 'head', 'align': HorizontalAlign.End },
              }
            )


          Image($r('app.media.express_check_expressage_delete'))
            .width(25)
            .height(25)
            .margin({ right: 10 })
            .alignRules({
              top: { anchor: '__container__', align: VerticalAlign.Top },
              bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
              right: { anchor: '__container__', align: HorizontalAlign.End }
            })
            .onClick(() => {
              AlertDialog.show(
                {
                  title: '温馨提示',
                  message: '确定要删除吗？',
                  autoCancel: true,
                  alignment: DialogAlignment.Bottom,
                  gridCount: 4,
                  primaryButton: {
                    value: '取消',
                    action: () => {
                      Log.info('Callback when the first button is clicked')
                    }
                  },
                  secondaryButton: {
                    enabled: true,
                    defaultFocus: true,
                    style: DialogButtonStyle.HIGHLIGHT,
                    value: '确认',
                    action: () => {
                      Log.info('Callback when the second button is clicked')
                      // TODO:删除快递详情
                      RdbManager.delExpressBeanForId(this.beannu).then((num) => {
                        if (num === 1) {
                          router.back()
                        } else {
                          Util.toast('删除失败')
                        }
                      })
                    }
                  },
                  cancel: () => {
                    Log.info('Closed callbacks')
                  },
                  onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
                    Log.info("reason=" + JSON.stringify(dismissDialogAction.reason))
                    Log.debug("dialog onWillDismiss")
                    if (dismissDialogAction.reason == DismissReason.PRESS_BACK) {
                      dismissDialogAction.dismiss()
                    }
                    if (dismissDialogAction.reason == DismissReason.TOUCH_OUTSIDE) {
                      dismissDialogAction.dismiss()
                    }
                  }
                }
              )
            })
        }
        .width('90%')
        .height('12%')
        .backgroundColor(Color.White)
        .padding(10)
        .borderRadius({
          topLeft: 12,
          topRight: 12,
          bottomLeft: 12,
          bottomRight: 12
        })

        List() {
          ForEach(this.info.data, (item: timeLine, index: number) => {
            ListItem() {
              Row() {
                Column({ space: 10 }) {
                  Text(item.time.toString().split(' ')[0])
                    .fontColor('#8085f7')
                    .fontSize(10)

                  Text(item.time.toString().split(' ')[1])
                    .fontColor('#8085f7')
                    .fontSize(12)
                }

                Column() {
                  Circle()
                    .width(10)
                    .height(10)
                    .fill(index === 0 ? Color.Green : Color.Gray)

                  Divider()
                    .vertical(true)
                    .width(10)
                    .height('10%')

                }.margin({
                  left: 10,
                  right: 10
                })

                Text(item.context + '')
                  .layoutWeight(1)// 设置为占据剩余空间
                  .fontSize(15)

              }.alignItems(VerticalAlign.Top)
            }
            .width('100%')
            .height('auto')
            .margin(5)
          })
        }
        .width('90%')
        .layoutWeight(1)
        .backgroundColor(Color.White)
        .padding(20)
        .borderRadius({
          topLeft: 12,
          topRight: 12,
          bottomLeft: 12,
          bottomRight: 12
        })

      }
      .width('100%')
      .height('90%')
      .margin({ top: 16 })
      .alignRules({
        top: { anchor: 'title_bar', align: VerticalAlign.Bottom },
        bottom: { anchor: View.container, align: VerticalAlign.Bottom }
      })
    }
    .height('100%')
    .width('100%')
  }
}

class ExpressResultModel {
  company: expCompany | null
  info: expInfo
  id: number

  constructor(company: expCompany | null, info: expInfo, id: number) {
    this.company = company
    this.info = info
    this.id = id
  }
}