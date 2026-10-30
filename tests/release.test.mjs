import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import { analyzeCommits } from '@semantic-release/commit-analyzer';
import { generateNotes } from '@semantic-release/release-notes-generator';

const config = JSON.parse(await readFile(new URL('../.releaserc.json', import.meta.url), 'utf8'));
const options = config.plugins.find(([name]) => name === '@semantic-release/commit-analyzer')[1];
const logger = { log() {}, error() {}, success() {} };

for (const [message, expected] of [
  ['feat(clock): add a setting', 'minor'],
  ['fix(clock): correct persistence', 'patch'],
  ['perf(clock): reduce reads', 'patch'],
  ['feat(clock)!: change the setting format', 'major'],
  ['fix: change format\n\nBREAKING CHANGE: old settings are incompatible', 'major'],
  ['docs: explain controls', null],
  ['ci: update test runner', null],
  ['chore: refresh tools', null],
]) {
  test(`${message.split('\n')[0]} selects ${expected ?? 'no release'}`, async () => {
    assert.equal(await analyzeCommits(options, { commits: [{ message }], logger, cwd: process.cwd() }), expected);
  });
}

test('release notes use the same Conventional Commits preset', async () => {
  const notesOptions = config.plugins.find(([name]) => name === '@semantic-release/release-notes-generator')[1];
  assert.equal(notesOptions.preset, options.preset);
  const notes = await generateNotes(notesOptions, {
    cwd: process.cwd(), logger,
    options: { repositoryUrl: 'https://github.com/Almewty/crystal-time-change.git' },
    commits: [{ hash: 'abcdef1234567890', message: 'feat(clock): add weekday editing' }],
    lastRelease: {}, nextRelease: { version: '1.0.0', gitTag: 'v1.0.0' },
  });
  assert.match(notes, /weekday editing/);
});

test('release is GitHub-only with archive preparation before asset publication', () => {
  assert.deepEqual(config.branches, ['main']);
  assert.equal(config.tagFormat, 'v${version}');
  assert.equal(config.plugins.some(([name]) => name === '@semantic-release/npm'), false);
  const execIndex = config.plugins.findIndex(([name]) => name === '@semantic-release/exec');
  const githubIndex = config.plugins.findIndex(([name]) => name === '@semantic-release/github');
  assert.ok(execIndex >= 0 && githubIndex > execIndex);
  assert.equal(config.plugins[execIndex][1].prepareCmd, 'python3 tools/package.py --version ${nextRelease.version}');
  const github = config.plugins[githubIndex][1];
  assert.equal(github.successComment, false);
  assert.equal(github.failComment, false);
  assert.equal(github.failTitle, false);
  assert.equal(github.assets.length, 2);
});
