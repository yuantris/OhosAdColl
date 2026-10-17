import { TitleBar } from '../common/view/TitleBar';
import { expCompany, NetList } from '../entity/ExpBeans';
import { router } from '@kit.ArkUI';
import RdbManager from '../common/zyhttp/RdbManager';
import Preference from '../common/util/Preference';
import Constants from '../common/Constants';
import { getCompanys } from '../service/default';
import { pinyin4js } from '@ohos/pinyin4js';
import { JsonParser, Log, ObjectGT, StrUtils } from '@zycore/common';

function getLogo(list: Array<expCompany>, netList: NetList[], index: number): string {
  const company = list.find(com => com.ccode === netList[index].companyNumber);
  return company?.logo ?? '';
}


@Entry
@Component
struct AreaListPage {
  @State message: string = 'Hello World';
  @State companyList: Array<expCompany> = []
  @State netList: NetList[] = [];

  aboutToAppear(): void {
    this.netList = router.getParams() as NetList[]

    Preference.getData(Constants.COMPANY).then((value) => {
      if (StrUtils.isBlank(value)) {
        getCompanys().then(coms => {
          if (!ObjectGT.isNull(coms)) {
            let list = coms as expCompany[]
            list.sort((a, b) => {
              let a_pin = getFirstLetter(a.cname);
              let b_pin = getFirstLetter(b.cname);
              // 使用 localeCompare 比较两个拼音首字母
              return a_pin.localeCompare(b_pin);
            });

            let json = JSON.stringify(list)
            Preference.writeData(Constants.COMPANY, json)
            this.companyList = list
          }
        }).catch((error: object) => {
          Log.error(`error : ${JSON.stringify(error)}`)
        })
      } else {
        this.companyList = JsonParser.jsonToArray<expCompany>(value)
      }
    })
  }

  build() {
    Column() {
      TitleBar(
        { title: '网点列表' }
      )

      RelativeContainer() {
        Text('该地区暂无网点列表')
          .width('100%')
          .height('100%')
          .textAlign(TextAlign.Center)
          .visibility(this.netList == null || this.netList.length == 0 ? Visibility.Visible : Visibility.None)

        List() {
          ForEach(this.netList, (item: NetList, index: number) => {
            ListItem() {
              Column() {
                RelativeContainer() {
                  Image(getLogo(this.companyList, this.netList, index))
                    .width(60)
                    .height(60)
                    .borderRadius(10)
                    .margin(10)
                    .id('logo')

                  Text(item.companyName)
                    .fontSize(18)
                    .margin({
                      left: 10
                    })
                    .alignRules({
                      top: { anchor: 'logo', align: VerticalAlign.Top },
                      left: { anchor: 'logo', align: HorizontalAlign.End }
                    })

                  Text(item.xzqFullName + ' ' + item.address)
                    .fontSize(14)
                    .margin({
                      left: 10
                    })
                    .alignRules({
                      bottom: { anchor: 'logo', align: VerticalAlign.Bottom },
                      left: { anchor: 'logo', align: HorizontalAlign.End }
                    })
                }.width('100%')
                .height(90)

                Text('客服电话 :' + item.telOne)
                  .fontSize(15)
                  .margin({
                    left: 20
                  })
              }
              .alignItems(HorizontalAlign.Start)
            }
            .width('95%')
            .height(120)
            .borderRadius(12)
            .backgroundColor(Color.White)
          })
        }
        .width('100%')
        .height('auto')
        .margin({
          top: 20
        })
        .visibility(this.netList == null || this.netList.length == 0 ? Visibility.None : Visibility.Visible)
        .alignListItem(ListItemAlign.Center)
      }

    }
    .height('100%')
    .width('100%')
    .backgroundColor('#f6f4f5')
  }
}

function getFirstLetter(cname: string | null): string {
  if (StrUtils.isBlank(cname)) {
    return '';
  }
  return pinyin4js.convertToPinyinString(cname, '', pinyin4js.FIRST_LETTER)
    .toUpperCase()
    .substring(0, 1);
}
