export default class RenderHelper {
  private constructor() {
  }

  private static instance = new RenderHelper();

  public static getInstance(): RenderHelper {
    return RenderHelper.instance;
  }


}