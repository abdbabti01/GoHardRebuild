// A STUB of Groq's Chat Completions endpoint for local journeys (docs/EATING_OUT.md › Verification, docs/COACH.md › Help
// with today). It is not a model: every Eating out request gets the same fixed structured reply, and a Help with today
// request a fixed rule (a word "fail" → HTTP 500; "smaller" → a smaller portion of the item discussed; a saved item whose
// name is in the words → that item, and "with 150 g of rice" → that food of it at those grams; "quick"/"protein"/"idea"
// with ideas available → two fixed ideas; otherwise "today"), so a real-app journey can exercise the app and API end to end
// without a key. Never point a deployed API at it.
//
//   node scripts/coach-stub.mjs [port]        (default 5137, bound to 127.0.0.1)
//   API env: GOHARD_Coach__Provider=Groq GOHARD_Coach__GroqApiKey=stub-not-a-key
//            GOHARD_Coach__GroqBaseUrl=http://127.0.0.1:5137/openai/v1
import http from 'node:http';

const port = +(process.argv[2] ?? 5137);
const reply = {
  kind: 'constraints', mode: 'choose', chainId: null, maxCalories: 600, minCalories: null, minProtein: 25,
  keep: [{ itemId: 'subway-ca:potato-rings-4', quantity: 1 }], exclude: [], prefer: [], avoid: [], priority: 'protein',
  clarification: null, unknownItems: [],
};
/** The fixed rule for a Help with today request (see the top of this file). */
function daily(user) {
  const request = (user.split('<request>\n').at(-1) ?? '').split('\n</request>')[0].toLowerCase();
  const items = [...user.matchAll(/^- ([mrf]\d+) \| (\w+) \| "(.*)"/gm)].map((m) => ({ ref: m[1], name: m[3].toLowerCase() }));
  const base = { kind: 'today', day: 'shown', nutrient: null, source: null, refs: [], change: null, factor: null, servings: null, grams: null, ingredient: null,
    maxCalories: null, minProtein: null, meal: null, clarification: null, unknownItems: [], ideas: [], preferences: [] };
  // "quick ... protein" with ideas available → two fixed ideas, one of them with a food no catalog has.
  if (/new ideas: available/i.test(user) && /quick|protein|idea/.test(request)) {
    return { ...base, kind: 'ideas', preferences: ['quick', 'moreProtein'], ideas: [
      { title: 'Eggs and toast', foods: [{ name: 'egg', label: 'Eggs', preparation: null, quantity: 2, unit: 'piece', noun: 'egg' }, { name: 'whole wheat bread', label: 'Toast', preparation: null, quantity: 1, unit: 'piece', noun: 'slice' }] },
      { title: 'Dragonfruit cup', foods: [{ name: 'dragonfruit zzz', label: 'Dragonfruit', preparation: null, quantity: 150, unit: 'g', noun: null }] },
    ] };
  }
  const named = items.filter((i) => i.name.split(/\s+/).every((w) => request.includes(w)));
  if (/smaller/.test(request)) return { ...base, kind: 'portion', change: 'smaller', refs: named.map((i) => i.ref) };
  // "<meal> but with 150 g of <food>": one food of that saved meal at the person's grams.
  const swap = request.match(/with (\d+) ?g of ([a-z ]+?)(?: today|$)/);
  if (named.length && swap) return { ...base, kind: 'portion', refs: named.map((i) => i.ref), grams: Number(swap[1]), ingredient: swap[2].trim() };
  if (named.length) return { ...base, kind: 'portion', refs: named.map((i) => i.ref) };
  return base;
}

http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => (body += c));
  req.on('end', () => {
    const asked = (() => { try { return JSON.parse(body); } catch { return {}; } })();
    const schema = asked.response_format?.json_schema?.name;
    console.log(`${new Date().toISOString()} ${req.method} ${req.url} schema=${schema}`);
    const user = asked.messages?.at(-1)?.content ?? '';
    if (schema === 'daily_coach_intent' && /\bfail\b/i.test(user.split('<request>').at(-1))) {
      res.writeHead(500, { 'content-type': 'application/json' });
      return res.end(JSON.stringify({ error: { message: 'stub failure', type: 'server_error' } }));
    }
    const content = schema === 'eating_out_preferences' ? JSON.stringify(reply)
      : schema === 'daily_coach_intent' ? JSON.stringify(daily(user))
      : JSON.stringify({ answer: 'Stub answer.', sources: [], proposal: null });
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ id: 'chatcmpl-stub', object: 'chat.completion', model: 'stub', choices: [{ index: 0, message: { role: 'assistant', content, refusal: null }, finish_reason: 'stop' }] }));
  });
}).listen(port, '127.0.0.1', () => console.log(`coach stub on http://127.0.0.1:${port}/openai/v1`));
