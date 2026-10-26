// A STUB of Groq's Chat Completions endpoint for local journeys (docs/EATING_OUT.md › Verification). It is not a model:
// every Eating out request gets the same fixed structured reply, so a real-app journey can exercise the app and API
// end to end without a key. Never point a deployed API at it.
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
http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => (body += c));
  req.on('end', () => {
    const asked = (() => { try { return JSON.parse(body); } catch { return {}; } })();
    const schema = asked.response_format?.json_schema?.name;
    console.log(`${new Date().toISOString()} ${req.method} ${req.url} schema=${schema}`);
    const content = schema === 'eating_out_preferences' ? JSON.stringify(reply) : JSON.stringify({ answer: 'Stub answer.', sources: [], proposal: null });
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ id: 'chatcmpl-stub', object: 'chat.completion', model: 'stub', choices: [{ index: 0, message: { role: 'assistant', content, refusal: null }, finish_reason: 'stop' }] }));
  });
}).listen(port, '127.0.0.1', () => console.log(`coach stub on http://127.0.0.1:${port}/openai/v1`));
