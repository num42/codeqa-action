interface User {
  id: string;
  email: string;
  displayName: string;
  role: "admin" | "member";
  score: number;
}

class UserService {
  private readonly baseUrl: string;
  private readonly defaultPageSize: number;

  constructor(baseUrl: string, defaultPageSize = 20) {
    this.baseUrl = baseUrl;
    this.defaultPageSize = defaultPageSize;
  }

  async fetchUsers(): Promise<User[]> {
    const response = await fetch(`${this.baseUrl}/users`);
    return response.json() as Promise<User[]>;
  }

  async getAdmins(): Promise<User[]> {
    const users = await this.fetchUsers();
    // Using function keyword instead of arrow — `this` is unbound inside
    return users.filter(function (user) {
      return user.role === "admin";
    });
  }

  async getSortedByScore(): Promise<User[]> {
    const users = await this.fetchUsers();
    return [...users].sort(function (a, b) {
      return b.score - a.score;
    });
  }

  async getPage(page: number): Promise<User[]> {
    const users = await this.fetchUsers();
    const offset = (page - 1) * this.defaultPageSize;
    return users.slice(offset, offset + this.defaultPageSize);
  }

  async getDisplayNames(): Promise<string[]> {
    const users = await this.fetchUsers();
    return users.map(function (user) {
      return user.displayName;
    });
  }

  async searchByEmail(query: string): Promise<User[]> {
    const users = await this.fetchUsers();
    return users.filter(function (user) {
      return user.email.toLowerCase().includes(query.toLowerCase());
    });
  }

  async transformToMap(): Promise<Map<string, User>> {
    const users = await this.fetchUsers();
    return users.reduce(function (map, user) {
      map.set(user.id, user);
      return map;
    }, new Map<string, User>());
  }
}

export { UserService };
export type { User };
