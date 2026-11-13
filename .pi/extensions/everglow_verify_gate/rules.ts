/**
 * Pure rules for the Everglow verify gate.
 *
 * The pi extension only wires tool calls to these functions, so the rules can
 * be tested with `node --test` and no pi runtime. Two holes this closes, both
 * seen in real sessions:
 *
 *   - Ordering. The old gate asked "did any verification run?", so an edit
 *     made after the checks still passed. PR 584 shipped an `Analysis: passed`
 *     line for a `flutter analyze` that had never run, because `flutter test`
 *     had already satisfied the single bucket.
 *   - Coverage. `Analysis:`, `Tests:` and the rest are separate claims. At PR
 *     time the gate now requires the signal behind each claim that the diff
 *     can make.
 */

export interface GateData {
	kind: "edit" | "verify" | "proof";
	path?: string;
	signal?: string;
}

export interface GateState {
	edited: Set<string>;
	verified: Set<string>;
	proofs: Set<string>;
	/** Monotonic position, so "after the last edit" is answerable. */
	seq: number;
	lastCodeEditSeq: number;
	lastVerifySeq: number;
}

/** Files that count as "real code". Docs, proof shots and CI yml do not. */
export const CODE_FILE =
	/^(lib\/.*\.dart|functions\/(?!.*\.md$).*\.js|test\/.*\.dart|tool\/.*\.dart)$/;

export const VERIFY_PATTERNS: Array<[RegExp, string]> = [
	[/\bflutter\s+analyze\b/, "flutter analyze"],
	[/\bflutter\s+test\b/, "flutter test"],
	[/\bdart\s+tool\/ci\/check_\w+\.dart\b/, "regression guard"],
	[/\bnpm\s+(--prefix\s+\S+\s+)?(test|run\s+test)\b/, "npm test"],
	[/\bnpm\s+(--prefix\s+\S+\s+)?run\s+verify\b/, "npm verify"],
	[/\bnode\s+(--?\S+\s+)*[\w./-]*eval_gate\.js\b/, "eval_gate.js"],
];

export function verifySignals(command: string): string[] {
	const hits: string[] = [];
	for (const [pattern, name] of VERIFY_PATTERNS) {
		if (pattern.test(command)) hits.push(name);
	}
	return hits;
}

export function createState(): GateState {
	return {
		edited: new Set(),
		verified: new Set(),
		proofs: new Set(),
		seq: 0,
		lastCodeEditSeq: -1,
		lastVerifySeq: -1,
	};
}

/** Apply one persisted gate entry. Callers bump `seq` for unrelated entries. */
export function applyEntry(state: GateState, data: GateData): void {
	const seq = state.seq++;
	if (data.kind === "edit" && data.path) {
		state.edited.add(data.path);
		if (CODE_FILE.test(data.path)) state.lastCodeEditSeq = seq;
	} else if (data.kind === "proof" && data.path) {
		state.proofs.add(data.path);
	} else if (data.kind === "verify" && data.signal) {
		state.verified.add(data.signal);
		state.lastVerifySeq = seq;
	}
}

export function codeFiles(state: GateState): string[] {
	return [...state.edited].filter((path) => CODE_FILE.test(path));
}

/** Why a commit is blocked, or null when it may proceed. */
export function commitBlockReason(state: GateState): string | null {
	const code = codeFiles(state);
	if (code.length === 0) return null;
	if (state.lastVerifySeq >= state.lastCodeEditSeq) return null;
	const ran = state.verified.size > 0;
	return (
		`verify-gate: ${ran ? "your last code edit came after the last verification" : "this session edited code but ran no verification"}. ` +
		`Edited: ${code.slice(0, 3).join(", ")}. ` +
		`Re-run the checks after your final edit: flutter analyze; ` +
		`flutter test --exclude-tags="golden,network"; dart tool/ci/check_*.dart; ` +
		`and flutter run -d chrome for UI changes. ` +
		`Legit exception: add "# verify-gate allow" to the command.`
	);
}

/**
 * Why opening a PR is blocked, or null. Only judges work this session did:
 * a session that edited nothing has nothing to answer for.
 */
export function prBlockReason(state: GateState): string | null {
	const code = codeFiles(state);
	if (code.length === 0) return null;

	const missing: string[] = [];
	if (code.some((path) => /^(lib|test)\/.*\.dart$/.test(path))) {
		for (const signal of ["flutter analyze", "flutter test"]) {
			if (!state.verified.has(signal)) missing.push(signal);
		}
	}
	if (code.some((path) => path.startsWith("functions/"))) {
		if (!state.verified.has("npm verify")) missing.push("npm run verify");
	}

	const stale = state.lastVerifySeq < state.lastCodeEditSeq;
	if (missing.length === 0 && !stale) return null;

	const todo: string[] = [];
	if (missing.length > 0) todo.push(`run ${missing.join(" and ")}`);
	if (stale) todo.push("re-run the checks after your last edit");
	return (
		`verify-gate: the PR body declares Analysis/Tests/Guards/Browser, but ` +
		`${todo.join("; ")}. ` +
		`Edited: ${code.slice(0, 3).join(", ")}. ` +
		`Legit exception: append "# verify-gate allow".`
	);
}

/**
 * True when the command creates a branch whose start point is the local
 * `main` ref. That ref goes stale (nothing fetches it), so a branch from it
 * silently starts on old code.
 */
export function startsFromMain(command: string): boolean {
	for (const segment of command.split(/[\n;]|&&|\|\|/)) {
		const tokens = segment.trim().split(/\s+/).filter(Boolean);
		if (tokens[0] !== "git") continue;
		if (tokens[1] !== "checkout" && tokens[1] !== "switch") continue;
		const flag = tokens.findIndex((token) => token === "-b" || token === "-c");
		if (flag < 0) continue;
		// git checkout -b <name> [<start>]
		if (tokens[flag + 2] === "main") return true;
	}
	return false;
}

export function staleMainReason(behind: number): string | null {
	if (!Number.isFinite(behind) || behind <= 0) return null;
	return (
		`verify-gate: local main is ${behind} commit(s) behind origin/main, so a ` +
		`branch from it starts on old code. Use: git fetch origin && ` +
		`git checkout -b <branch> origin/main. ` +
		`Legit exception: append "# verify-gate allow".`
	);
}

export function statusLines(state: GateState): string[] {
	const code = codeFiles(state);
	return [
		`code files edited : ${code.length ? code.join(", ") : "none"}`,
		`verification seen : ${state.verified.size ? [...state.verified].join(", ") : "NONE — commit gate is armed"}`,
		`pr proofs written : ${state.proofs.size ? [...state.proofs].join(", ") : "none — gh pr create is armed"}`,
	];
}
