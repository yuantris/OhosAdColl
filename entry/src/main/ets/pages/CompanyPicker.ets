import { TitleBar } from '../common/view/TitleBar';
import { router } from '@kit.ArkUI';
import { expCompany } from '../entity/ExpBeans';
import Preference from '../common/util/Preference';
import Constants from '../common/Constants';
import { pinyin4js } from '@ohos/pinyin4js';
import { getCompanys } from '../service/default';
import { JsonParser, Log, StrUtils } from '@zycore/common';

@Entry
@Component
struct CompanyPicker {
  @State companyList: Array<expCompany> = []
  @State selectIndex: number = 0;
  private listScroller: Scroller = new Scroller()
  private value: string[] = ['A', 'B', 'C', 'D', 'E', 'F', 'G',
    'H', 'I', 'J', 'K', 'L', 'M', 'N',
    'O', 'P', 'Q', 'R', 'S', 'T', 'U',
    'V', 'W', 'X', 'Y', 'Z']

  aboutToAppear(): void {

    Preference.getData(Constants.COMPANY).then((value) => {
      if (StrUtils.isBlank(value)) {

        getCompanys()
          .then(coms => {
            if (coms) {
              Log.debug(`companyList: ${JSON.stringify(coms)}`)

              const list = coms as expCompany[];

              // 排序公司列表，按拼音首字母排序
              list.sort((a, b) => {
                const a_pin = getFirstLetter(a.cname);
                const b_pin = getFirstLetter(b.cname);
                return a_pin.localeCompare(b_pin); // 使用 localeCompare 比较拼音首字母
              });

              const json = JSON.stringify(list);
              Preference.writeData(Constants.COMPANY, json);
              this.companyList = list;
            }
          })
          .catch((error: object) => {
            Log.error(`Error: ${JSON.stringify(error)}`);
          });

      } else {
        this.companyList = JsonParser.jsonToArray<expCompany>(value)
      }
    })

  }

  build() {

    Column() {
      TitleBar({
        title: '选择公司'
      })

      Search({ value: undefined, placeholder: undefined })
        .searchIcon({
          src: $r('app.media.express_check_company_so_icon')
        })
        .width('90%')
        .height(40)
        .maxLength(20)
        .backgroundColor('#F5F5F5')
        .placeholderColor(Color.Grey)
        .placeholderFont({ size: 14, weight: 400 })
        .textFont({ size: 14, weight: 400 })
        .margin(20)
        .onSubmit((value: string) => {
          if (!this.companyList || this.companyList.length === 0 || !value) {
            return;
          }
          const index = this.companyList.findIndex(item => item.cname?.includes(value))
          if (index !== -1) {
            this.listScroller.scrollToIndex(index);
          }
        })

      Row() {
        List({ scroller: this.listScroller }) {
          ForEach(this.companyList, (item: expCompany) => {
            ListItem() {
              Column() {
                Row() {
                  Image(item?.logo || $r('app.media.express_default'))
                    .width(40)
                    .height(40)
                    .borderRadius(50)
                    .margin(10)

                  Text(item.cname)
                }
                .width('100%')
                .justifyContent(FlexAlign.Start)

                Divider().strokeWidth(1).color('#F1F3F5').width('83%')
              }.alignItems(HorizontalAlign.End)

            }.onClick(() => {

              const params = router.getParams();
              if (JSON.stringify(params).includes('express')) {
                router.back({ url: 'pages/ExpressInfoSearch', params: item })
              } else {
                router.back({ url: 'pages/Index', params: item })
              }
            })
          })
        }
        .width('90%')
        .height('100%')
        .scrollBarWidth(0)
        .onScrollIndex((index: number) => {
          const company = this.companyList[index];
          const cname = company?.cname || ''; // 检查 company 和 cname 是否存在
          if (!cname) {
            Log.warn(`Company name is empty or undefined at index:${index}`);
            return;
          }
          let pinyin: string = pinyin4js.convertToPinyinString(cname, '', pinyin4js.FIRST_LETTER)
            .toUpperCase()
            .charAt(0);
          this.selectIndex = this.value.findIndex((item) => item === pinyin);
        })

        AlphabetIndexer({ arrayValue: this.value, selected: 0 })
          .autoCollapse(false)
          .selectedColor(0xFFFFFF)// 选中项文本颜色
          .popupColor(0xFFFAF0)// 弹出框文本颜色
          .selectedBackgroundColor(0xCCCCCC)// 选中项背景颜色
          .popupBackground(0xD2B48C)// 弹出框背景颜色
          .usingPopup(true)// 是否显示弹出框
          .selectedFont({ size: 16, weight: FontWeight.Normal })// 选中项字体样式
          .popupFont({ size: 30, weight: FontWeight.Bolder })// 弹出框内容的字体样式
          .itemSize(20)// 每一项的尺寸大小
          .alignStyle(IndexerAlign.Right)// 弹出框在索引条右侧弹出
          .popupItemBorderRadius(24)// 设置提示弹窗索引项背板圆角半径
          .itemBorderRadius(14)// 设置索引项背板圆角半径
          .popupBackgroundBlurStyle(BlurStyle.Regular)// 设置提示弹窗的背景模糊材质
          .popupTitleBackground(0xCCCCCC)// 设置提示弹窗首个索引项背板颜色
          .popupSelectedColor(0x00FF00)
          .popupUnselectedColor(0x0000FF)
          .popupItemFont({ size: 30, style: FontStyle.Normal })
          .popupItemBackgroundColor(0xCCCCCC)
          .selected(this.selectIndex)
          .margin({ bottom: 30 })
          .onSelect((index: number) => {
            let letter = this.value[index]
            let a = this.companyList.findIndex((company) => {
              const cname = company?.cname || ''; // 确保 cname 不为 undefined 或 null
              return getFirstLetter(cname) === letter;
            });
            if (a !== -1) {
              this.listScroller.scrollToIndex(a);
            }
            Log.info(this.value[index] + ' Selected!')
          })
          .onPopupSelect((index: number) => {
            Log.info('onPopupSelected:' + index)
          })
          .height('100%')
      }
      .layoutWeight(1)

    }
    .height('100%')
    .width('100%')

  }
}

function getFirstLetter(str: string | null): string {
  const validStr = str ?? ''; // 处理 null 情况
  if (!validStr.trim()) {
    return '';
  }

  return pinyin4js
    .convertToPinyinString(validStr, '', pinyin4js.FIRST_LETTER)
    .toUpperCase()
    .charAt(0);
}
