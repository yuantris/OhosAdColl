import { FilterWord } from '@csj/openadsdk';



/**
 * 自定义弹窗组件
 * @param onSelected ： filterItem 被点击时回调 ,【需要把该回调的执行透传给CSJ SDK】
 * @param onOtherSuggestComment 弹窗二级建议弹窗后，当点击内容提交时需回调【需要把该回调的执行透传给CSJ SDK】
 * @param onUserSuggestDialogCancel 弹窗二级建议弹窗Close后，需回调次接口，同时回传用户建议内容【需要把该回调的执行透传给CSJ SDK】
 */
@Builder
export function customDislikeComponent(fwList: Array<FilterWord>,
  onSelected: (filterPosition: number, filterName: string) => void,
  onOtherSuggestComment: (suggestionValue: string) => void,
  onUserSuggestDialogCancel: (commentValue: string) => void) {
  //自定义Dislike弹窗
  CSJDislikeComponent({
    _fwList:fwList,
    _onSelected: onSelected,
    _onOtherSuggestComment: onOtherSuggestComment,
    _onUserSuggestDialogCancel: onUserSuggestDialogCancel
  });
}


/**
 * 自定义Dislike弹窗组件
 */
@Component
export default struct CSJDislikeComponent {
  private _onSelected?: (filterPosition: number, filterName: string) => void;
  private _onOtherSuggestComment?: (suggestionValue: string) => void;
  private _onUserSuggestDialogCancel?: (commentValue: string) => void;
  private _fwList?: Array<FilterWord>;

  build() {
    Column() {
      List() {
        //filterWords列表
        ForEach(this._fwList, (item: FilterWord, index: number) => {
          ListItem() {
            this.filterWordsItem(item, index)
          }
          .padding({
            left: 8,
            right: 8,
            top: 14,
            bottom: 14
          })
        }, (item: string) => JSON.stringify(item))

        //反馈建议
        ListItem() {
          UserSuggestComment({
            onOtherSuggestComment: this._onOtherSuggestComment,
            onUserSuggestDialogCancel: this._onUserSuggestDialogCancel
          })
        }
        .padding({
          left: 8,
          right: 8,
          top: 14,
          bottom: 8
        }
        )
      }
      .width("100%")
      .divider({ strokeWidth: '0.5vp', color: '#030161823' })
    }
    .width("100%")
    .padding({
      top: '6vp',
      bottom: '6vp'
    })
    .borderRadius('8vp',)
  }

  @Builder
  filterWordsItem(fw: FilterWord, position: number) {
    if (fw) {
      if (fw.getOptions() && fw.getOptions().length > 0) {
        Column() {
          //一级item
          this.filterWordOnly(fw.getName(), position);
          //二级item
          this.optionItem(fw, position);
        }
        .justifyContent(FlexAlign.Start)
      } else {
        this.filterWordOnly(fw.getName(), position);
      }
    }
  }

  /**
   * 一级选项
   * @param name
   * @param filterItemIds
   */
  @Builder
  filterWordOnly(name: string, position: number) {
    Text(name)
      .fontSize('14fp')
      .fontColor("#161823")
      .alignSelf(ItemAlign.Start)
      .padding({
        left: 6
      })//filterItem被点击------------调用onSelected通知sdk-----------------
      .onClick(() => {
        if (this._onSelected) {
          this._onSelected(position, name);
        }
      })
  }

  /**
   * 二级选项
   * @param name
   * @param filterItemIds
   */
  @Builder
  optionItem(fw: FilterWord, position: number) {
    List({ space: 0 }) {
      ForEach(fw.getOptions(), (fwItem: FilterWord) => {
        ListItem() {
          Text(fwItem.getName())
            .fontSize('12fp')
            .fontWeight(FontWeight.Lighter)
        }
        .backgroundColor("#20161823")
        .borderRadius('2vp')
        .margin({ left: 8, top: 8 })
        .padding({
          left: 8,
          right: 8,
          bottom: 4,
          top: 4
        })
        //filterItem被点击------------调用onSelected通知sdk-----------------
        .onClick(() => {
          if (this._onSelected) {
            this._onSelected(position, fwItem.getName());
          }
        })
      }, (fwItem: FilterWord) => JSON.stringify(fwItem))
    }
    .enableScrollInteraction(false)
    .width("60%")
    .lanes({ minLength: 80, maxLength: 80 })
    .scrollBar(BarState.Off)
  }
}

/**
 * 用户其它建议Component
 */
@Component
export struct UserSuggestComment {
  onOtherSuggestComment?: (suggestionValue: string) => void;
  onUserSuggestDialogCancel?: (commentValue: string) => void;
  //二级弹窗控制器
  private _suggestionDialogController?: CustomDialogController = new CustomDialogController({
    builder: CustomSuggestionDialog({
      _cancelListener: this.onUserSuggestDialogCancel,
      _commitListener: this.onOtherSuggestComment
    }),
    alignment: DialogAlignment.Bottom,
    customStyle: true,
    offset: { dx: 0, dy: -20 }
  });

  build() {
    Row() {
      Image($r('app.media.tt_dislike_suggestion_logo'))
        .size({ width: 12, height: 12 })
        .margin({ left: 6 })

      Text("其它建议")
        .fontSize('12fp')
        .fontColor("#80161823")
        .margin({ left: 4 })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .border({ width: 0.5, color: "#10161823" })
    .borderRadius('4vp')
    .onClick((event: ClickEvent) => {
      this._suggestionDialogController?.open();
    })
  }
}


/**
 * 二级弹窗，填写具体建议
 */
@CustomDialog
export struct CustomSuggestionDialog {
  private _suggestionDialogController: CustomDialogController
  @State _hasContent: boolean = false; //
  private _cancelListener?: (suggestContent: string) => void; //点击close关闭弹窗回调
  private _commitListener?: (suggestContent: string) => void; //内容提交回调
  private _suggestContent: string = ""; //建议内容

  build() {
    Column() {
      Row() {
        //关闭按钮
        Image($r("app.media.tt_dislike"))
          .objectFit(ImageFit.Auto)
          .size({
            width: '20vp',
            height: '20vp'
          })
          .onClick((event: ClickEvent) => {
            this._suggestionDialogController?.close();
          })

        //其它建议
        Text("其它建议")
          .fontSize('16fp')
          .fontColor("#80323232")
          .padding({ left: '8vp', right: '8vp' })

        //提交
        Text("提交")
          .fontSize('16fp')
          .fontColor(this._hasContent ? "#323232" : "#80323232")
          .onClick(() => {
            if (this._hasContent) {
              if (this._commitListener) {
                this._commitListener(this._suggestContent); //提交内容处理【------该回调的执行需要透传给CSJ SDK--------】
              }
              this._suggestionDialogController.close(); //关闭弹窗
            }
          }).padding({ left: '8vp', right: '8vp' })
      }
      .padding({
        left: '16vp',
        right: '16vp',
        top: '14vp',
        bottom: '14vp',
      })
      .width("100%")
      .justifyContent(FlexAlign.SpaceBetween)


      //分割线
      Divider().strokeWidth(0.5).color('#20161823').width("98%")

      //内容
      TextArea({ placeholder: "请具体说明问题，我们将尽快处理" })
        .placeholderColor("#57161823")
        .fontSize('16fp')
        .width("100%")
        .maxLines(7)
        .maxLength(500)
        .backgroundColor(Color.White)
        .onChange((value: string) => {
          this._hasContent = (value?.length >= 3) ? true : false;
          this._suggestContent = value;
        })
    }
    .width("94%")
    .height("30%")
    .backgroundColor(Color.White)
    .borderRadius('8vp')
    .onDisAppear(() => {
      if (this._cancelListener) {
        this._cancelListener(this._suggestContent);//【------该回调的执行需要透传给CSJ SDK--------】
      }
    })
  }
}
