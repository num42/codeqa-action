var STOP_WORDS = ["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for"];

function tokenize(text) {
  var normalized = text.toLowerCase().replace(/[^\w\s]/g, " ");
  var parts = normalized.split(/\s+/);
  var result = [];
  for (var i = 0; i < parts.length; i++) {
    var token = parts[i];
    if (token.length > 1 && STOP_WORDS.indexOf(token) === -1) {
      result.push(token);
    }
  }
  return result;
}

function buildIndex(documents) {
  var index = {};

  for (var d = 0; d < documents.length; d++) {
    var doc = documents[d];
    var tokens = tokenize(doc.content);
    var seen = {};

    for (var t = 0; t < tokens.length; t++) {
      var token = tokens[t];
      if (!seen[token]) {
        seen[token] = true;
        if (!index[token]) {
          index[token] = [];
        }
        index[token].push(doc.id);
      }
    }
  }

  return index;
}

function search(index, query) {
  var queryTokens = tokenize(query);
  if (queryTokens.length === 0) return [];

  var results = null;

  for (var i = 0; i < queryTokens.length; i++) {
    var token = queryTokens[i];
    var matches = index[token] || [];
    if (results === null) {
      results = matches.slice();
    } else {
      var filtered = [];
      for (var j = 0; j < results.length; j++) {
        if (matches.indexOf(results[j]) !== -1) {
          filtered.push(results[j]);
        }
      }
      results = filtered;
    }
  }

  return results || [];
}

export { buildIndex, search, tokenize };
