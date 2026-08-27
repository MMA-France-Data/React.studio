const C = {
  reset: '\x1b[0m', dim: '\x1b[2m', bold: '\x1b[1m',
  red: '\x1b[31m', green: '\x1b[32m', yellow: '\x1b[33m', cyan: '\x1b[36m',
};

const enabled = process.stdout.isTTY && !process.env.NO_COLOR;
const paint = (c, s) => (enabled ? c + s + C.reset : s);

let stepIndex = 0;

export const log = {
  step(title) {
    stepIndex += 1;
    console.log('\n' + paint(C.bold, `[${stepIndex}] ${title}`));
  },
  info(msg) { console.log('    ' + msg); },
  detail(msg) { console.log('    ' + paint(C.dim, msg)); },
  ok(msg) { console.log('    ' + paint(C.green, 'OK  ') + msg); },
  warn(msg) { console.warn('    ' + paint(C.yellow, 'ATT ') + msg); },
  error(msg) { console.error('    ' + paint(C.red, 'ERR ') + msg); },
  result(msg) { console.log('\n' + paint(C.cyan, msg)); },
  reset() { stepIndex = 0; },
};
