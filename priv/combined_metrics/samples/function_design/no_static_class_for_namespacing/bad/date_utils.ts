class DateUtils {
  static formatDate(date: Date | string | number, locale = "en-US"): string {
    return new Intl.DateTimeFormat(locale, {
      year: "numeric",
      month: "short",
      day: "numeric",
    }).format(new Date(date));
  }

  static formatDateTime(date: Date | string | number, locale = "en-US"): string {
    return new Intl.DateTimeFormat(locale, {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    }).format(new Date(date));
  }

  static isToday(date: Date | string | number): boolean {
    const d = new Date(date);
    const now = new Date();
    return (
      d.getFullYear() === now.getFullYear() &&
      d.getMonth() === now.getMonth() &&
      d.getDate() === now.getDate()
    );
  }

  static addDays(date: Date, days: number): Date {
    const result = new Date(date);
    result.setDate(result.getDate() + days);
    return result;
  }

  static differenceInDays(a: Date, b: Date): number {
    const msPerDay = 1000 * 60 * 60 * 24;
    return Math.round((a.getTime() - b.getTime()) / msPerDay);
  }

  static startOfDay(date: Date): Date {
    const result = new Date(date);
    result.setHours(0, 0, 0, 0);
    return result;
  }

  static endOfDay(date: Date): Date {
    const result = new Date(date);
    result.setHours(23, 59, 59, 999);
    return result;
  }

  static parseIsoDate(isoString: string): Date {
    const date = new Date(isoString);
    if (Number.isNaN(date.getTime())) {
      throw new RangeError(`Invalid ISO date string: '${isoString}'`);
    }
    return date;
  }
}

export { DateUtils };
