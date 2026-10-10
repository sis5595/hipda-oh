// Offline production-method regressions. Never installs an app or contacts 4D4Y.
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const compilerArgument = process.argv[2];
if (!compilerArgument || !fs.existsSync(compilerArgument)) {
  console.error('Usage: node run-regressions.cjs <path-to-SDK-typescript.js>');
  process.exit(2);
}
const compiler = path.resolve(compilerArgument);
const tests = fs.readdirSync(__dirname).filter(name => name.endsWith('.test.cjs')).sort();
if (tests.length === 0) {
  console.error('No regression suites found.');
  process.exit(2);
}
const failed = [];
for (const name of tests) {
  console.log(`\n[${name}]`);
  const result = spawnSync(process.execPath, [path.join(__dirname, name), compiler], {
    cwd: __dirname,
    stdio: 'inherit',
    timeout: 60000,
    windowsHide: true,
    shell: false
  });
  if (result.error || result.status !== 0) {
    failed.push(name);
    console.error(`FAILED ${name}${result.error ? ': ' + result.error.message : ''}`);
  }
}
console.log(`\nRegression suites: ${tests.length - failed.length}/${tests.length} passed.`);
if (failed.length) {
  console.error('Failed suites: ' + failed.join(', '));
  process.exitCode = 1;
}
