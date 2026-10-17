/**
 * AbilityHooks — Ability / Index 生命周期钩子的默认实现。
 *
 * 此处为 no-op 占位，可被对应构建变体下的同名 export 覆盖。
 * 修改任一 export 签名时，请保持各变体之间签名一致。
 */
import { Want } from '@kit.AbilityKit';

/** Ability onCreate 钩子。 */
export function onAbilityCreate(_want: Want): void {
}

/** Ability onNewWant 钩子。 */
export function onAbilityNewWant(_want: Want): void {
}

/** Ability onDestroy 钩子。 */
export function onAbilityDestroy(): void {
}

/** Index aboutToAppear 钩子。 */
export function onIndexAboutToAppear(_pathStack: NavPathStack): void {
}

/** Index aboutToDisappear 钩子。 */
export function onIndexAboutToDisappear(): void {
}
