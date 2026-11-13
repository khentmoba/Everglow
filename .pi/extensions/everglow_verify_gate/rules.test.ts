import test from "node:test";
import assert from "node:assert/strict";
import {
	applyEntry,
	commitBlockReason,
	createState,
	prBlockReason,
	staleMainReason,
	startsFromMain,
	verifySignals,
	type GateData,
	type GateState,
} from "./rules.ts";

function run(entries: GateData[]): GateState {
	const state = createState();
	for (const entry of entries) applyEntry(state, entry);
	return state;
}

const edit = (path: string): GateData => ({ kind: "edit", path });
const verify = (signal: string): GateData => ({ kind: "verify", signal });

const READER = "lib/features/manga/presentation/screens/katana_reader_screen.dart";
const READER_TEST = "test/features/manga/katana_reader_chrome_test.dart";

test("verifySignals maps the commands the skill tells agents to run", () => {
	assert.deepEqual(verifySignals("flutter analyze"), ["flutter analyze"]);
	assert.deepEqual(verifySignals('flutter test --exclude-tags="golden,network"'), ["flutter test"]);
	assert.deepEqual(verifySignals("dart tool/ci/check_release_sync.dart"), ["regression guard"]);
	assert.deepEqual(verifySignals("npm run verify"), ["npm verify"]);
	assert.deepEqual(verifySignals("git status"), []);
});

test("commit is blocked when code was edited and nothing was verified", () => {
	const reason = commitBlockReason(run([edit(READER)]));
	assert.match(reason ?? "", /ran no verification/);
});

test("commit is blocked when the last edit came after the last verification", () => {
	const reason = commitBlockReason(run([edit(READER), verify("flutter analyze")]));
	assert.equal(reason, null, "verification after the edit should pass");

	const stale = commitBlockReason(
		run([edit(READER), verify("flutter analyze"), edit(READER)]),
	);
	assert.match(stale ?? "", /came after the last verification/);
});

test("commit ignores docs, proof shots and CI yml", () => {
	assert.equal(commitBlockReason(run([edit("docs/PERF_NOTES.md")])), null);
	assert.equal(commitBlockReason(run([edit("docs/pr-proof/pr-1/shot.png")])), null);
	assert.equal(commitBlockReason(run([edit(".github/workflows/quality.yml")])), null);
});

// The exact shape of PR 584: analyze never ran, the test file was added after
// the only verification, and the PR body still said "Analysis: passed".
test("PR is blocked when the claimed analyze never ran", () => {
	const state = run([
		edit(READER),
		verify("flutter test"),
		edit(READER_TEST),
	]);
	const reason = prBlockReason(state);
	assert.match(reason ?? "", /flutter analyze/);
});

test("PR passes when both Dart checks ran after the last edit", () => {
	const state = run([
		edit(READER),
		edit(READER_TEST),
		verify("flutter analyze"),
		verify("flutter test"),
	]);
	assert.equal(prBlockReason(state), null);
});

test("PR is blocked when verification is older than the last edit", () => {
	const state = run([
		edit(READER),
		verify("flutter analyze"),
		verify("flutter test"),
		edit(READER),
	]);
	assert.match(prBlockReason(state) ?? "", /re-run the checks after your last edit/);
});

test("PR needs npm run verify for functions/", () => {
	const fn = "functions/index.js";
	assert.match(prBlockReason(run([edit(fn), verify("npm test")])) ?? "", /npm run verify/);
	assert.equal(prBlockReason(run([edit(fn), verify("npm verify")])), null);
});

test("PR says nothing when this session edited no code", () => {
	assert.equal(prBlockReason(run([verify("flutter test")])), null);
	assert.equal(prBlockReason(run([])), null);
});

test("state rebuilds in order, so resume cannot reorder the evidence", () => {
	const entries: GateData[] = [
		verify("flutter analyze"),
		verify("flutter test"),
		edit(READER),
	];
	const rebuilt = run(entries);
	assert.match(commitBlockReason(rebuilt) ?? "", /came after the last verification/);
	assert.match(prBlockReason(rebuilt) ?? "", /re-run the checks/);
});

test("startsFromMain only fires when main is the start point", () => {
	assert.equal(startsFromMain("git checkout -b fix/x main"), true);
	assert.equal(startsFromMain("git switch -c feat/y main"), true);
	assert.equal(startsFromMain("git fetch origin && git checkout -b fix/z main"), true);
	assert.equal(startsFromMain("git checkout -b fix/x origin/main"), false);
	assert.equal(startsFromMain("git checkout -b fix/x"), false);
	assert.equal(startsFromMain("git checkout -b fix/main-thing"), false);
	assert.equal(startsFromMain("git checkout main"), false);
});

test("a stale main is reported with the number of commits behind", () => {
	assert.equal(staleMainReason(0), null);
	assert.equal(staleMainReason(-1), null);
	assert.match(staleMainReason(381) ?? "", /381 commit\(s\) behind origin\/main/);
});
