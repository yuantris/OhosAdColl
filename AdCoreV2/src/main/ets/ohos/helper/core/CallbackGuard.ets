import { LogManager } from '../logger/LogManager';

export class CallbackGuard {
  private triggeredCallbacks: Set<string> = new Set()

  guard(callbackName: string, callback: () => void): void {
    if (!this.triggeredCallbacks.has(callbackName)) {
      this.triggeredCallbacks.add(callbackName)
      try {
        callback()
      } catch (e) {
        LogManager.warn('CallbackGuard', `Callback ${callbackName} threw error: ${e}`)
      }
    }
  }

  reset(): void {
    this.triggeredCallbacks.clear()
  }

  isTriggered(callbackName: string): boolean {
    return this.triggeredCallbacks.has(callbackName)
  }
}
