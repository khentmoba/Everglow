/**
 * Everglow verify gate
 *
 * Turns the mechanical parts of our "proof before PR" workflow into code,
 * so they stop being advice the model can skim. Three narrow checks, one
 * status command:
 *
 *   A. Commiting real code changes requires verification that is NEWER than
 *      the last code edit. Running the checks and then editing again leaves
 *      the claim stale; that is how PR 584 shipped an `Analysis: passed` line
 *      for a `flutter analyze` that had never run.
 *   B. Commands that reference tool/ci/check_*.dart or dart tool/<x>.dart
 *      for scripts that don't exist are blocked and corrected with the
 *      real guard list. (Rule 3: never invent a verification command.)
 *   C. `gh pr create` / `gh pr ready` needs a proof image written under
 *      docs/pr-proof/ during this session, and the signal behind each claim
 *      the diff can make: `flutter analyze` + `flutter test` for Dart,
 *      `npm run verify` for functions/. (Rule 2: evidence matches the claim.)
 *
 * The rules live in rules.ts so `node --test` can exercise them without the
 * pi runtime. Keep helpers in this directory: pi loads every top-level file
 * in `.pi/extensions/` as an extension, so a bare module there fails startup.
 *
 * Design notes:
 *   - State is rebuilt from persisted session entries, so fork/resume/
 *     compaction don't erase "what ran".
 *   - Non-interactive mode (pi -p, CI) downgrades blocks to notices,
 *     except B which is mechanical and safe everywhere.
 *   - `# verify-gate allow` in a command is a one-shot escape hatch.
 */

import { existsSync } from "node:fs";
import { isToolCallEventType, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import {
	applyEntry,
	commitBlockReason,
	createState,
	prBlockReason,
	staleMainReason,
	startsFromMain,
	statusLines,
	verifySignals,
	type GateData,
	type GateState,
} from "./rules.ts";

const CUSTOM_TYPE = "everglow-verify-gate";

function segments(command: string): string[] {
	return command
		.split(/[\n;]|&&|\|\|/)
		.map((s) => s.trim())
		.filter(Boolean);
}

function leadingCommands(command: string): string[] {
	return segments(command).map((s) => {
		const tokens = s.split(/\s+/);
		// strip simple leading env assignments: FOO=bar git commit ...
		let i = 0;
		while (i < tokens.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(tokens[i])) i++;
		return tokens.slice(i, i + 3).join(" ");
	});
}

export default function (pi: ExtensionAPI) {
	let state: GateState | null = null;

	// Proof shots usually come from a browser or bash, not edit/write, so also
	// accept images that git sees on this branch (committed, staged, or untracked).
	async function branchHasProof(ctx: ExtensionContext): Promise<boolean> {
		const isImage = (p: string) => /^docs\/pr-proof\/.+\.(png|jpe?g|webp|gif)$/i.test(p.trim());
		const git = async (args: string[]) => {
			const r = await pi.exec("git", ["-C", ctx.cwd, ...args], { timeout: 5_000 });
			return r.code === 0 ? r.stdout.split("\n") : [];
		};
		const committed = await git(["diff", "--name-only", "origin/main...HEAD", "--", "docs/pr-proof"]);
		const pending = (await git(["status", "--porcelain", "--untracked-files=all", "--", "docs/pr-proof"])).map((l) => l.slice(3));
		return [...committed, ...pending].some(isImage);
	}

	async function mainBehindOrigin(ctx: ExtensionContext): Promise<number> {
		const r = await pi.exec("git", ["-C", ctx.cwd, "rev-list", "--count", "main..origin/main"], { timeout: 5_000 });
		if (r.code !== 0) return 0;
		const count = Number(r.stdout.trim());
		return Number.isFinite(count) ? count : 0;
	}

	function getState(ctx: ExtensionContext): GateState {
		if (state) return state;
		state = createState();
		for (const entry of ctx.sessionManager.getBranch() as Array<{ type: string; customType?: string; data?: GateData }>) {
			if (entry.type === "custom" && entry.customType === CUSTOM_TYPE && entry.data) {
				applyEntry(state, entry.data);
			} else {
				state.seq++; // keep ordering honest against unrelated entries
			}
		}
		return state;
	}

	function record(ctx: ExtensionContext, data: GateData): void {
		applyEntry(getState(ctx), data);
		pi.appendEntry<GateData>(CUSTOM_TYPE, data);
	}

	pi.registerEntryRenderer<GateData>(CUSTOM_TYPE, (entry, _opts, theme) => {
		const d = entry.data;
		if (!d) return new Text("", 0, 0);
		let label: string;
		if (d.kind === "verify") label = `verified: ${d.signal}`;
		else if (d.kind === "proof") label = `proof: ${d.path}`;
		else label = `touched: ${d.path}`;
		return new Text(theme.fg("dim", `  [verify-gate] ${label}`), 0, 0);
	});

	// --- signal collection -------------------------------------------------

	pi.on("tool_call", async (event, ctx) => {
		const s = getState(ctx);

		if (isToolCallEventType("edit", event) || isToolCallEventType("write", event)) {
			const path = event.input.path.replace(/\\/g, "/");
			const cwd = ctx.cwd.replace(/\\/g, "/");
			const rel = path.toLowerCase().startsWith(`${cwd.toLowerCase()}/`) ? path.slice(cwd.length + 1) : path;
			if (rel && !s.edited.has(rel) && !path.includes("/.pi/")) {
				record(ctx, { kind: "edit", path: rel });
			}
			if (rel.startsWith("docs/pr-proof/") && /\.(png|jpe?g|webp|gif)$/i.test(rel)) {
				record(ctx, { kind: "proof", path: rel });
			}
			return undefined;
		}

		if (isToolCallEventType("bash", event)) {
			const command = event.input.command;

			// Gate D: a branch from a stale local `main` starts on old code.
			if (startsFromMain(command) && !/#\s*verify-gate\s+allow/i.test(command)) {
				const reason = staleMainReason(await mainBehindOrigin(ctx));
				if (reason) return { block: true, reason };
			}

			// Gate B: invented dart tool scripts.
			const refs = [...command.matchAll(/\bdart\s+((?:\/\S+\/)?tool\/[\w/]+\.dart)/g)].map((m) => m[1]);
			for (const ref of refs) {
				const abs = ref.startsWith("/") ? ref : `${ctx.cwd}/${ref}`;
				if (!existsSync(abs)) {
					const guards = await listGuards(ctx);
					return {
						block: true,
						reason: `verify-gate: ${ref} does not exist. Real CI guards: ${guards.join(", ") || "tool/ci/ is empty"}. Never invent a verification command — reuse what the repo has (AGENTS.md, or the everglow-pr skill).`,
					};
				}
			}

			for (const signal of verifySignals(command)) record(ctx, { kind: "verify", signal });

			// Gate A: a commit needs verification newer than the last code edit.
			const commits = leadingCommands(command).some((c) => /^git\s+(commit|push)\b/.test(c));
			if (commits) {
				if (/#\s*verify-gate\s+allow/i.test(command)) return undefined;
				const reason = commitBlockReason(s);
				if (reason) {
					if (!ctx.hasUI) {
						ctx.ui.notify(`Blocking commit without fresh verification (non-interactive)`, "warning");
					}
					return { block: true, reason };
				}
			}

			// Gate C: PR creation needs proof shots and the signals behind the
			// claims the diff makes.
			const opensPr = leadingCommands(command).some((c) => /^gh\s+pr\s+(create|ready)\b/.test(c));
			if (opensPr) {
				if (/#\s*verify-gate\s+allow/i.test(command)) return undefined;
				const reason = prBlockReason(s);
				if (reason) return { block: true, reason };
				if (s.proofs.size === 0 && !(await branchHasProof(ctx))) {
					const msg =
						`verify-gate: every PR shows proof — save a screenshot of the changed screen under ` +
						`docs/pr-proof/pr-<N>/shot-<name>.png first (fake demo data only; see the everglow-pr skill), ` +
						`then reference it in the PR body. Legit exception: append "# verify-gate allow".`;
					return { block: true, reason: msg };
				}
			}
			return undefined;
		}

		// A live /flutter-run debug session counts as "ran the product".
		if (event.toolName.startsWith("flutter_debug")) {
			record(ctx, { kind: "verify", signal: "flutter-run debug session" });
		}
		return undefined;
	});

	// User-bash (! commands) also count as verification. event.command is the
	// documented field for this event; returning undefined lets local execution proceed.
	pi.on("user_bash", async (event, ctx) => {
		for (const signal of verifySignals(event.command)) record(ctx, { kind: "verify", signal });
		return undefined;
	});

	async function listGuards(ctx: ExtensionContext): Promise<string[]> {
		try {
			const { stdout } = await pi.exec("ls", [`${ctx.cwd}/tool/ci`]);
			return stdout.trim().split("\n").filter((l) => l.endsWith(".dart"));
		} catch {
			return [];
		}
	}

	// --- status ------------------------------------------------------------

	pi.registerCommand("verify-gate", {
		description: "Show what this session edited, verified, and proofed (Everglow gate status)",
		handler: async (_args, ctx) => {
			ctx.ui.notify(statusLines(getState(ctx)).join("\n"), "info");
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		state = null; // force rebuild from (possibly resumed) session
		getState(ctx);
	});
}
