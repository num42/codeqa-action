defmodule Test.Fixtures.Dart.MixinComposition do
  @moduledoc false
  use Test.LanguageFixture, language: "dart mixin_composition"

  @code ~S'''
  abstract class Serializable {
  Map<String, dynamic> toJson();

  String toJsonString() {
    final map = toJson();
    return map.entries.map((e) => '"${e.key}": "${e.value}"').join(', ');
  }
  }

  abstract class Validatable {
  List<String> validate();

  bool get isValid => validate().isEmpty;

  void assertValid() {
    final errors = validate();
    if (errors.isNotEmpty) throw ArgumentError(errors.join(', '));
  }
  }

  abstract class Equatable {
  List<Object?> get props;

  bool equalsTo(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    final otherEquatable = other as Equatable;
    for (int i = 0; i < props.length; i++) {
      if (props[i] != otherEquatable.props[i]) return false;
    }
    return true;
  }
  }

  class Address extends Serializable implements Validatable {
  final String street;
  final String city;
  final String country;

  Address({required this.street, required this.city, required this.country});

  Map<String, dynamic> toJson() => {'street': street, 'city': city, 'country': country};

  List<String> validate() {
    final errors = <String>[];
    if (street.isEmpty) errors.add('street is required');
    if (city.isEmpty) errors.add('city is required');
    if (country.isEmpty) errors.add('country is required');
    return errors;
  }

  List<Object?> get props => [street, city, country];
  }

  enum AddressType {
  home,
  work,
  billing,
  shipping
  }

  class Contact extends Serializable implements Validatable {
  final String name;
  final String email;
  final Address address;

  Contact({required this.name, required this.email, required this.address});

  Map<String, dynamic> toJson() => {'name': name, 'email': email, 'address': address.toJson()};

  List<String> validate() {
    final errors = <String>[];
    if (name.isEmpty) errors.add('name is required');
    if (!email.contains('@')) errors.add('invalid email');
    errors.addAll(address.validate());
    return errors;
  }
  }
  '''
end
