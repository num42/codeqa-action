defmodule Test.Fixtures.Java.RepositoryPattern do
  @moduledoc false
  use Test.LanguageFixture, language: "java repository_pattern"

  @code ~S'''
  interface Entity<ID> {
    ID getId();
  }

  interface Repository<T extends Entity<ID>, ID> {
    T findById(ID id);
    java.util.List<T> findAll();
    T save(T entity);
    void delete(ID id);
    boolean exists(ID id);
  }

  interface UserRepository extends Repository<User, Long> {
    java.util.Optional<User> findByEmail(String email);
    java.util.List<User> findByRole(String role);
  }

  class User implements Entity<Long> {
    private Long id;
    private String name;
    private String email;
    private String role;

    public User(Long id, String name, String email, String role) {
      this.id = id;
      this.name = name;
      this.email = email;
      this.role = role;
    }

    public Long getId() { return id; }

    public String getName() { return name; }

    public String getEmail() { return email; }

    public String getRole() { return role; }
  }

  class InMemoryUserRepository implements UserRepository {
    private final java.util.Map<Long, User> store = new java.util.HashMap<>();
    private long nextId = 1L;

    public User findById(Long id) { return store.get(id); }

    public java.util.List<User> findAll() { return new java.util.ArrayList<>(store.values()); }

    public User save(User user) {
      if (user.getId() == null) {
        User saved = new User(nextId++, user.getName(), user.getEmail(), user.getRole());
        store.put(saved.getId(), saved);
        return saved;
      }
      store.put(user.getId(), user);
      return user;
    }

    public void delete(Long id) { store.remove(id); }

    public boolean exists(Long id) { return store.containsKey(id); }

    public java.util.Optional<User> findByEmail(String email) {
      return store.values().stream().filter(u -> u.getEmail().equals(email)).findFirst();
    }

    public java.util.List<User> findByRole(String role) {
      return store.values().stream().filter(u -> u.getRole().equals(role)).collect(java.util.stream.Collectors.toList());
    }
  }
  '''
end
