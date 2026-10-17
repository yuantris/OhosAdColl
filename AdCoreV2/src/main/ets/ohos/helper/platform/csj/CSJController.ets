import { CSJCustomPrivacyController } from "@csj/openadsdk";

export class CSJController extends CSJCustomPrivacyController{
  isCanUseAppTrackingConsent(): boolean {
    return true;
  }
}