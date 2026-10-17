export class AdError extends Error {
  readonly code: number;

  constructor(code: number, message: string) {
    super(`code=${code}: ${message}`);
    this.code = code;
    this.name = 'AdError';
  }

  static fromError(error: Error | undefined): AdError {
    if (error instanceof AdError) {
      return error;
    }
    if (error instanceof Error) {
      // 仅当 message 明确携带 code= 时解析；避免启发式误抽（替代旧 parseFromMessage 魔法码）
      const codeMatch = error.message.match(/^code=(\d+):/);
      if (codeMatch) {
        return new AdError(parseInt(codeMatch[1], 10), error.message);
      }
      return new AdError(0, error.message);
    }
    return new AdError(0, String(error));
  }
}
