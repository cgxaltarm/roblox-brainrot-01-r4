// Brainrot Night Market — make.fun roblox-brainrot-01 entry program.
// Node 22, standard library only. It hands the game in: game.rbxl (the
// Rojo-built place), src/ (every Luau script of the place), screenshots/
// (3-4 Studio captures, first by name is the Roblox thumbnail) and
// PLAY.json (the published public place) are copied from beside this file
// into /output, and /output/dossier.json is written with the vendored
// make.fun library so the scorer can check the entry byte for byte.
//
// Run it the way the grader does, with out/ standing in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
//
// Names under /output must start with a letter, a digit or _ and hold only
// letters, digits, . _ and - : anything dotted (.gitkeep, .DS_Store, .git)
// copied in fails the entry, so both directory copies skip dotted names.

import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync } from "node:fs";
import { basename, join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildDossier } from "./vendor/makefun-roblox.ts";

const repoRoot = fileURLToPath(new URL(".", import.meta.url));
const outDir = process.env.MAKEFUN_OUTPUT_DIR ?? "/output";

const notDotted = (path: string): boolean => !basename(path).startsWith(".");

mkdirSync(outDir, { recursive: true });
copyFileSync(join(repoRoot, "game.rbxl"), join(outDir, "game.rbxl"));
copyFileSync(join(repoRoot, "PLAY.json"), join(outDir, "PLAY.json"));
cpSync(join(repoRoot, "src"), join(outDir, "src"), { recursive: true, filter: notDotted });
mkdirSync(join(outDir, "screenshots"), { recursive: true });
if (existsSync(join(repoRoot, "screenshots"))) {
	cpSync(join(repoRoot, "screenshots"), join(outDir, "screenshots"), { recursive: true, filter: notDotted });
}

writeFileSync(
	join(outDir, "dossier.json"),
	buildDossier(outDir, {
		text_max_bytes: 65536,
		screenshots: { max: 4, max_bytes: 262144 },
		max_instances: 500000,
		scripts_max_source_bytes: 8388608,
		scripts_max_path_chars: 1048576,
	}),
);
