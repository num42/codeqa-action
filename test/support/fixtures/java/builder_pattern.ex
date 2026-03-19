defmodule Test.Fixtures.Java.BuilderPattern do
  @moduledoc false
  use Test.LanguageFixture, language: "java builder_pattern"

  @code ~S'''
  interface Validatable {
    boolean isValid();
    String validationError();
  }

  interface Buildable<T> {
    T build();
  }

  class Address implements Validatable {
    private final String street;
    private final String city;
    private final String country;
    private final String postalCode;

    private Address(Builder b) {
      this.street = b.street;
      this.city = b.city;
      this.country = b.country;
      this.postalCode = b.postalCode;
    }

    public boolean isValid() {
      return street != null && !street.isEmpty() && city != null && country != null;
    }

    public String validationError() {
      if (street == null || street.isEmpty()) return "street is required";
      if (city == null) return "city is required";
      return null;
    }

    public String getStreet() { return street; }

    public String getCity() { return city; }

    public String getCountry() { return country; }

    public String getPostalCode() { return postalCode; }

    public static class Builder implements Buildable<Address> {
      private String street;
      private String city;
      private String country;
      private String postalCode;

      public Builder street(String street) { this.street = street; return this; }

      public Builder city(String city) { this.city = city; return this; }

      public Builder country(String country) { this.country = country; return this; }

      public Builder postalCode(String postalCode) { this.postalCode = postalCode; return this; }

      public Address build() {
        Address a = new Address(this);
        if (!a.isValid()) throw new IllegalStateException(a.validationError());
        return a;
      }
    }
  }

  enum Country {
    US("United States"),
    DE("Germany"),
    JP("Japan"),
    BR("Brazil");

    private final String displayName;

    Country(String displayName) { this.displayName = displayName; }

    public String getDisplayName() { return displayName; }
  }
  '''
end
