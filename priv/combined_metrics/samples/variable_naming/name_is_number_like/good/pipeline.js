// Data pipeline with meaningful variable names.
// GOOD: variables like validatedInput, normalizedData, enrichedRecord describe their state.

async function run(input) {
  try {
    const validatedInput = validate(input);
    const normalizedData = normalize(validatedInput);
    const enrichedRecord = await enrich(normalizedData);
    const transformedRecord = transform(enrichedRecord);
    const formattedOutput = formatOutput(transformedRecord);
    return { ok: true, data: formattedOutput };
  } catch (error) {
    return { ok: false, error: error.message };
  }
}

function processUsers(users) {
  const activeUsers = filterActive(users);
  const usersWithProfiles = loadProfiles(activeUsers);
  const authorizedUsers = applyPermissions(usersWithProfiles);
  const sortedUsers = sortUsers(authorizedUsers);
  return sortedUsers;
}

function deduplicate(items) {
  const sortedItems = [...items].sort();
  const uniqueItems = [...new Set(sortedItems)];
  const presentItems = uniqueItems.filter(item => item != null);
  return presentItems;
}

async function retry(func, maxAttempts) {
  const initialResult = await attempt(func);
  if (initialResult.ok) return initialResult;

  const retryResult = await attempt(func);
  if (retryResult.ok) return retryResult;

  const finalResult = await attempt(func);
  if (finalResult.ok) return finalResult;

  return { ok: false, error: 'All retries failed' };
}

function mergeRecords(primaryRecord, secondaryRecord) {
  const merged = { ...primaryRecord, ...secondaryRecord };
  const cleaned = cleanNulls(merged);
  const withMetadata = addMetadata(cleaned);
  const validatedResult = validateMerged(withMetadata);
  return validatedResult;
}

function batchProcess(items, batchSize) {
  const batches = chunkArray(items, batchSize);
  const processedBatches = batches.map(processBatch);
  const flattenedResults = processedBatches.flat();
  return flattenedResults;
}

function buildPipeline(firstStage, secondStage, thirdStage) {
  return function (input) {
    const afterFirst = firstStage(input);
    const afterSecond = secondStage(afterFirst);
    return thirdStage(afterSecond);
  };
}

function validate(input) { return input; }
function normalize(data) { return data; }
async function enrich(data) { return data; }
function transform(data) { return data; }
function formatOutput(data) { return data; }
function filterActive(users) { return users.filter(u => u.active); }
function loadProfiles(users) { return users; }
function applyPermissions(users) { return users; }
function sortUsers(users) { return users.sort((a, b) => a.name.localeCompare(b.name)); }
async function attempt(func) { try { return { ok: true, data: await func() }; } catch (e) { return { ok: false }; } }
function cleanNulls(obj) { return Object.fromEntries(Object.entries(obj).filter(([, v]) => v != null)); }
function addMetadata(obj) { return { ...obj, processedAt: new Date() }; }
function validateMerged(obj) { return obj; }
function processBatch(batch) { return batch; }
function chunkArray(arr, size) { const chunks = []; for (let i = 0; i < arr.length; i += size) chunks.push(arr.slice(i, i + size)); return chunks; }

module.exports = { run, processUsers, deduplicate, retry, mergeRecords, batchProcess, buildPipeline };
