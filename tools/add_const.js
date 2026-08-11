const fs = require("fs");
const path = require("path");

const files = [
  "lib/features/cinema/presentation/widgets/episode_drawer.dart",
  "lib/features/watch_party/presentation/screens/watch_party_screen.dart",
  "lib/features/cinema/presentation/screens/anime_screen.dart",
  "lib/features/academy/screens/academy_hub_screen.dart",
  "lib/features/ai/presentation/widgets/mochi_screen.dart",
  "lib/features/manga/presentation/screens/manga_library_screen.dart",
  "lib/features/cinema/presentation/screens/video_player_screen.dart",
  "lib/features/dashboard/presentation/widgets/shelf_widgets.dart",
  "lib/features/starlight_jar/presentation/screens/starlight_jar_widget.dart",
  "lib/features/books/presentation/screens/books_screen.dart",
  "lib/features/books/presentation/screens/reader_screen.dart",
  "lib/features/cinema/presentation/screens/cinema_screen.dart",
  "lib/features/dashboard/presentation/widgets/creator_modal.dart",
  "lib/features/cinema/presentation/widgets/tabs/cinema_search_tab.dart",
  "lib/features/cinema/presentation/widgets/netflix/netflix_poster_card.dart",
  "lib/features/canvas/presentation/screens/canvas_screen.dart",
];

function addConst(match, full) {
  return "const " + full;
}

const patterns = [
  [/(?<!const )EdgeInsets\.all\((\s*\d+(?:\.\d+)?)\)/g],
  [/(?<!const )EdgeInsets\.symmetric\(([^)]*)\)/g],
  [/(?<!const )EdgeInsets\.only\(([^)]*)\)/g],
  [/(?<!const )EdgeInsets\.zero/g],
  [/(?<!const )Duration\(milliseconds:\s*(\d+)\)/g],
  [/(?<!const )Duration\(seconds:\s*(\d+)\)/g],
  [/(?<!const )Duration\(minutes:\s*(\d+)\)/g],
  [/(?<!const )BorderRadius\.circular\((\d+(?:\.\d+)?)\)/g],
  [/(?<!const )BorderRadius\.vertical\(([^)]*)\)/g],
  [/(?<!const )Radius\.circular\((\d+(?:\.\d+)?)\)/g],
  [/(?<!const )Radius\.zero/g],
  [/(?<!const )BorderRadius\.zero/g],
  [/(?<!const )FontWeight\.w\d+/g],
  [/(?<!const )FontWeight\.bold/g],
  [/(?<!const )FontWeight\.normal/g],
];

let totalChanges = 0;

for (const file of files) {
  const filePath = path.resolve(file);
  if (!fs.existsSync(filePath)) {
    console.log("  SKIP (not found): " + file);
    continue;
  }
  let content = fs.readFileSync(filePath, "utf8");
  const original = content;

  for (const [re] of patterns) {
    content = content.replace(re, (match) => "const " + match);
  }

  if (content !== original) {
    const count = (content.match(/const const /g) || []).length;
    if (count > 0) {
      content = content.replace(/const const /g, "const ");
    }
    fs.writeFileSync(filePath, content, "utf8");
    const changes = original.split("\n").length - content.split("\n").length;
    // Just count occurrences of new "const " that weren't there before
    const origConsts = (original.match(/\bconst\b/g) || []).length;
    const newConsts = (content.match(/\bconst\b/g) || []).length;
    const diff = newConsts - origConsts;
    totalChanges += diff;
    console.log("  " + file + ": " + diff + " const additions");
  } else {
    console.log("  " + file + ": no changes");
  }
}

console.log("\nTotal const additions: " + totalChanges);
