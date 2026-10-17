import { BuilderNode, NodeController, UIContext } from '@kit.ArkUI';
import { AdParams, buildHwAd } from './AdParams';
import { advertising } from '@kit.AdsKit';
import { ADHelper } from '../helper/ADHelper';

export class AdNodeController extends NodeController {
  private textNode: BuilderNode<[AdParams]> | null = null;
  private ads: Array<advertising.Advertisement> = [{
    adType: -1
  } as advertising.Advertisement]
  private options: advertising.AdDisplayOptions | undefined = undefined

  constructor(ads: Array<advertising.Advertisement>, options: advertising.AdDisplayOptions | undefined) {
    super();
    this.ads = ads
    this.options = options
  }

  makeNode(context: UIContext): FrameNode | null {
    if (this.textNode == null) {
      this.textNode = new BuilderNode(context);
      this.textNode.build(wrapBuilder<[AdParams]>(buildHwAd), new AdParams(this.ads, this.options));
    }
    // // 创建BuilderNode实例
    // this.textNode = new BuilderNode(context);
    // // 使用build方法构建组件树
    // this.textNode.build(wrapBuilder<[AdParams]>(buildHwAd), new AdParams(this.ads, this.options));
    // 返回需要显示的节点
    return this.textNode.getFrameNode();
  }
}