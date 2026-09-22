/**
 * Everglow verify gate
 *
 * Turns the mechanical parts of our "proof before PR" workflow into code,
 * so they stop being advice the model can skim. Three narrow checks, one
 * status command:
 *
 *   A. Commiting real code changes requires that this session also RAN
 *      verification (flutter analyze / flutter test / dart tool/ci/* /
 *      npm test in functions / node eval_gate.js / a flutter-run debug
 *      session). Blocked only when nothing ran at all — CI still catches
 *      failures, so we don't gate on green output.
 *   B. Commands that reference tool/ci/check_*.dart or dart tool/<x>.dart
 *      for scripts that don't exist are blocked and corrected with the
 *      real guard list. (Rule 3: never invent a verification command.)
 *   C. `gh pr create` / `gh pr ready` needs a proof image written under
 *      docs/pr-proof/ during this session. (Rule 2: evidence matches the
 *      claim.)
 *
 * Design notes:
 *   - State is rebuilt from persisted session entries, so fork/resume/
 *     compaction don't erase "what ran".
 *   - Non-interactive mode (pi -p, CI) downgrades blocks to notices,
 *     except B which is mechanical and safe everywhere.
 *   - `# verify-gate allow` in a commit message is a one-shot escape
 *     hatch for the rare legitimate exception.
 */

import { existsSync } from "node:fs";
import { isToolCallEventType, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

const CUSTOM_TYPE = "everglow-verify-gate";

interface GateData {
	kind: "edit" | "verify" | "proof";
	path?: string;
	signal?: string;
}

interface GateState {
	edited: Set<string>;
	verified: Set<string>;
	proofs: Set<string>;
}

const VERIFY_PATTERNS: Array<[RegExp, string]> = [
	[/\bflutter\s+analyze\b/, "flutter analyze"],
	[/\bflutter\s+test\b/, "flutter test"],
	[/\bdart\s+tool\/ci\/check_\w+\.dart\b/, "regression guard"],
	[/\bnpm\s+(--prefix\s+\S+\s+)?(test|run\s+test)\b/, "npm test"],
	[/\bnode\s+(--?\S+\s+)*[\w./-]*eval_gate\.js\b/, "eval_gate.js"],
];

// Files that count as "real code" for gate A. Docs, changelogs, proof
// shots, and CI yml can be committed without a verify signal.
const CODE_FILE = /^(lib\/.*\.dart|functions\/(?!.*\.md$).*\.js|test\/.*\.dart|tool\/.*\.dart)$/;

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

function verifySignals(command: string): string[] {
	const hits: string[] = [];
	for (const [pattern, name] of VERIFY_PATTERNS) {
		if (pattern.test(command)) hits.push(name);
	}
	return hits;
}

export default function (pi: ExtensionAPI) {
	let state: GateState | null = null;

	function freshState(): GateState {
		return { edited: new Set(), verified: new Set(), proofs: new Set() };
	}

	function getState(ctx: ExtensionContext): GateState {
		if (state) return state;
		state = freshState();
		for (const entry of ctx.sessionManager.getBranch() as Array<{ type: string; customType?: string; data?: GateData }>) {
			if (entry.type !== "custom" || entry.customType !== CUSTOM_TYPE || !entry.data) continue;
			const { kind, path, signal } = entry.data;
			if (kind === "edit" && path) state.edited.add(path);
			if (kind === "proof" && path) state.proofs.add(path);
			if (kind === "verify" && signal) state.verified.add(signal);
		}
		return state;
	}

	function record(ctx: ExtensionContext, data: GateData): void {
		const s = getState(ctx);
		if (data.kind === "edit" && data.path) s.edited.add(data.path);
		if (data.kind === "proof" && data.path) s.proofs.add(data.path);
		if (data.kind === "verify" && data.signal) s.verified.add(data.signal);
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
			const path = event.input.path;
			const rel = path.startsWith(ctx.cwd + "/") ? path.slice(ctx.cwd.length + 1) : path;
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

			// Gate B: invented dart tool scripts.
			const refs = [...command.matchAll(/\bdart\s+((?:\/\S+\/)?tool\/[\w/]+\.dart)/g)].map((m) => m[1]);
			for (const ref of refs) {
				const abs = ref.startsWith("/") ? ref : `${ctx.cwd}/${ref}`;
				if (!existsSync(abs)) {
					const guards = await listGuards(ctx);
					return {
						block: true,
						reason: `verify-gate: ${ref} does not exist. Real CI guards: ${guards.join(", ") || "tool/ci/ is empty"}. Never invent a verification command — reuse what the repo has (AGENTS.md, Definition of done).`,
					};
				}
			}

			for (const signal of verifySignals(command)) record(ctx, { kind: "verify", signal });

			// Gate A: commit requires that some verification ran.
			const commits = leadingCommands(command).some((c) => /^git\s+(commit|push)\b/.test(c));
			if (commits) {
				if (/#\s*verify-gate\s+allow/i.test(command)) return undefined;
				const codeChanges = [...s.edited].filter((p) => CODE_FILE.test(p));
				if (codeChanges.length > 0 && s.verified.size === 0) {
					const msg =
						`verify-gate: this session edited ${codeChanges.length} code file(s) ` +
						`(e.g. ${codeChanges.slice(0, 3).join(", ")}) but ran no verification yet. ` +
						`Run first: flutter analyze; flutter test --exclude-tags="golden,network"; dart tool/ci/check_*.dart as relevant; ` +
						`and actually run the app (flutter run -d chrome) for UI changes. ` +
						`Legit exception (docs-only misclassified etc.): add "# verify-gate allow" to the command.`;
					if (!ctx.hasUI) {
						ctx.ui.notify(`Blocking commit without verification (non-interactive)`, "warning");
					}
					return { block: true, reason: msg };
				}
			}

			// Gate C: PR creation needs session-written proof shots.
			const opensPr = leadingCommands(command).some((c) => /^gh\s+pr\s+(create|ready)\b/.test(c));
			if (opensPr) {
				if (/#\s*verify-gate\s+allow/i.test(command)) return undefined;
				if (s.proofs.size === 0) {
					const msg =
						`verify-gate: every PR shows proof — save a screenshot of the changed screen under ` +
						`docs/pr-proof/pr-<N>/shot-<name>.png first (fake demo data only; see preview-flutter-web-ui skill), ` +
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
			const s = getState(ctx);
			const code = [...s.edited].filter((p) => CODE_FILE.test(p));
			const lines = [
				`code files edited : ${code.length ? code.join(", ") : "none"}`,
				`verification seen : ${s.verified.size ? [...s.verified].join(", ") : "NONE — commit gate is armed"}`,
				`pr proofs written : ${s.proofs.size ? [...s.proofs].join(", ") : "none — gh pr create is armed"}`,
			];
			ctx.ui.notify(lines.join("\n"), "info");
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		state = null; // force rebuild from (possibly resumed) session
		getState(ctx);
	});
}
