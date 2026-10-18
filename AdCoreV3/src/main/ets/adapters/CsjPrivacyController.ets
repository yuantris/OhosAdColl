import { CSJCustomPrivacyController } from '@csj/openadsdk';

/** Privacy controller kept local to V3; V3 does not depend on V2 source files. */
export class CsjPrivacyController extends CSJCustomPrivacyController {
  isCanUseAppTrackingConsent(): boolean { return true; }
}
