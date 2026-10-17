import { ComponentContent, promptAction } from '@kit.ArkUI';
import { Ohos } from '@zycore/common';
import { BusinessError } from '@kit.BasicServicesKit';

interface DialogVM {
  com: ComponentContent<object>;
}

export class DialogGT {
  private static instance: DialogGT;
  private dialogs: DialogVM[] = new Array<DialogVM>();
  private isShowing: boolean = false

  static getInstance(): DialogGT {
    if (!DialogGT.instance) {
      DialogGT.instance = new DialogGT();
    }
    return DialogGT.instance;
  }

  static showDialog<T extends object>(contentView: WrappedBuilder<[T]>, args: T,
    options?: promptAction.BaseDialogOptions, delay: number = 200, uiContext?: UIContext): void {
    if (uiContext) {
      let prompt = uiContext.getPromptAction();
      let componentContent = new ComponentContent(uiContext, contentView, args);
      let customOptions: promptAction.BaseDialogOptions = options ?? {
        autoCancel: false,
        alignment: DialogAlignment.Center
      };

      let dialogs = DialogGT.getInstance().dialogs;
      let info: DialogVM = {
        com: componentContent,
      };
      dialogs[0] = info;
      prompt.openCustomDialog(componentContent, customOptions).then(() => {
        DialogGT.instance.isShowing = true
      }).catch(() => {

      })
    } else {
      setTimeout(() => {
        let uiContext = Ohos.getUIContext();
        if (uiContext) {
          let prompt = uiContext.getPromptAction();
          let componentContent = new ComponentContent(uiContext, contentView, args);
          let customOptions: promptAction.BaseDialogOptions = options ?? {
            autoCancel: false,
            alignment: DialogAlignment.Center
          };

          let dialogs = DialogGT.getInstance().dialogs;
          let info: DialogVM = {
            com: componentContent,
          };
          dialogs[0] = info;
          prompt.openCustomDialog(componentContent, customOptions).then(() => {
            DialogGT.instance.isShowing = true
          })
        }
      }, delay)
    }
  }

  static closeDialog(): void {
    try {
      let uiContext = Ohos.getUIContext();
      if (uiContext && DialogGT.instance.dialogs.length > 0) {
        let prompt = uiContext.getPromptAction();
        let sameTypeList = DialogGT.instance.dialogs;
        let info = sameTypeList[sameTypeList.length - 1];
        if (info && info.com) {
          DialogGT.getInstance().dialogs = DialogGT.instance.dialogs.filter((model) => {
            return model.com !== info.com;
          });
          prompt.closeCustomDialog(info.com);
          DialogGT.instance.isShowing = false;
        }
      }
    } catch (e) {
    }
  }

  static showPopView<T extends object>(contentView: WrappedBuilder<[T]>, args: T,
    options?: promptAction.BaseDialogOptions, delay: number = 200, uiContext?: UIContext): void {
    DialogGT.showDialog(contentView, args, options, delay, uiContext);
  }

  static closePopView(): void {
    DialogGT.closeDialog();
  }

  static isShowing() {
    return DialogGT.instance.isShowing
  }
}
