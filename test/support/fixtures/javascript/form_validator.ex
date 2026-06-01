defmodule Test.Fixtures.JavaScript.FormValidator do
  @moduledoc false
  use Test.LanguageFixture, language: "javascript form_validator"

  @code ~S'''
  class ValidationError {
    constructor(field, message) {
      this.field = field;
      this.message = message;
    }

    toString() {
      return `${this.field}: ${this.message}`;
    }
  }

  class ValidationResult {
    constructor() {
      this.errors = [];
    }

    addError(field, message) {
      this.errors.push(new ValidationError(field, message));
      return this;
    }

    isValid() {
      return this.errors.length === 0;
    }

    getErrors(field) {
      return this.errors.filter(function(e) { return e.field === field; });
    }
  }

  class FieldValidator {
    constructor(field, value) {
      this.field = field;
      this.value = value;
      this._rules = [];
    }

    required() {
      this._rules.push(function(v) {
        if (v === null || v === undefined || v === "") {
          return "is required";
        }
        return null;
      });
      return this;
    }

    minLength(n) {
      this._rules.push(function(v) {
        if (typeof v === "string" && v.length < n) {
          return "is too short (minimum " + n + " characters)";
        }
        return null;
      });
      return this;
    }

    maxLength(n) {
      this._rules.push(function(v) {
        if (typeof v === "string" && v.length > n) {
          return "is too long (maximum " + n + " characters)";
        }
        return null;
      });
      return this;
    }

    matches(pattern, message) {
      this._rules.push(function(v) {
        if (typeof v === "string" && !pattern.test(v)) {
          return message || "is invalid";
        }
        return null;
      });
      return this;
    }

    validate() {
      var errors = [];
      for (var i = 0; i < this._rules.length; i++) {
        var error = this._rules[i](this.value);
        if (error !== null) {
          errors.push(error);
        }
      }
      return errors;
    }
  }

  class FormValidator {
    constructor(data) {
      this._data = data;
      this._fields = [];
    }

    field(name) {
      var validator = new FieldValidator(name, this._data[name]);
      this._fields.push(validator);
      return validator;
    }

    validate() {
      var result = new ValidationResult();
      for (var i = 0; i < this._fields.length; i++) {
        var f = this._fields[i];
        var errors = f.validate();
        for (var j = 0; j < errors.length; j++) {
          result.addError(f.field, errors[j]);
        }
      }
      return result;
    }
  }

  function validateEmail(value) {
    var pattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return pattern.test(value);
  }

  function validateUrl(value) {
    try {
      new URL(value);
      return true;
    } catch (_) {
      return false;
    }
  }
  '''
end
