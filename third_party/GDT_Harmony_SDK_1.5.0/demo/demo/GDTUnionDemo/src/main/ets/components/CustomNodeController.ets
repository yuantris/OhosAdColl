import { BuilderNode, FrameNode, NodeController } from '@kit.ArkUI';

export class CustomNodeController<T extends Object> extends NodeController {
  private builderNode?: BuilderNode<[T]>;
  private readonly wrapBuilder: WrappedBuilder<[T]>;
  private readonly param?: T;

  public constructor(wrapBuilder: WrappedBuilder<[T]>, param?: T) {
    super();
    this.wrapBuilder = wrapBuilder;
    this.param = param;
  }

  public makeNode(uiContext: UIContext): FrameNode | null {
    if (this.builderNode == null) {
      this.builderNode = new BuilderNode(uiContext);
      this.builderNode.build(this.wrapBuilder, this.param);
    }
    return this.builderNode.getFrameNode();
  }
}
