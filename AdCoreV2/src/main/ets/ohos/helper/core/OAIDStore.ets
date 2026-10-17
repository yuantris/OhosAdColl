export class OAIDStore {
  private static _OAID: string = ''

  static get OAID(): string { return OAIDStore._OAID }
  static set OAID(value: string) { OAIDStore._OAID = value }
}
