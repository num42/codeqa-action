const STOP_WORDS = new Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for"]);

function tokenize(text) {
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, " ")
    .split(/\s+/)
    .filter((token) => token.length > 1 && !STOP_WORDS.has(token));
}

function buildIndex(documents) {
  const index = new Map();

  for (const doc of documents) {
    const tokens = tokenize(doc.content);
    const uniqueTokens = new Set(tokens);

    for (const token of uniqueTokens) {
      if (!index.has(token)) {
        index.set(token, []);
      }
      index.get(token).push(doc.id);
    }
  }

  return index;
}

function search(index, query) {
  const queryTokens = tokenize(query);

  if (queryTokens.length === 0) return [];

  const matchingSets = queryTokens.map((token) => new Set(index.get(token) ?? []));

  const [first, ...rest] = matchingSets;
  const results = [...first].filter((docId) =>
    rest.every((set) => set.has(docId))
  );

  return results;
}

function rankResults(results, index, queryTokens) {
  const scores = results.map((docId) => {
    const score = queryTokens.reduce((total, token) => {
      const docs = index.get(token) ?? [];
      const termFrequency = docs.filter((id) => id === docId).length;
      return total + termFrequency;
    }, 0);
    return { docId, score };
  });

  return scores.sort((a, b) => b.score - a.score).map((r) => r.docId);
}

export { buildIndex, search, rankResults, tokenize };
