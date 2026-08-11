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

// Patterns to match lines where a widget can have const prepended
// Each pattern matches the indentation + widget and replaces with const version
const linePatterns = [
  // SizedBox with height only (single line)
  [/^(\s+)(SizedBox\(\s*height:\s*-?\d+(?:\.\d+)?\s*\))/gm],
  // SizedBox with width only (single line)
  [/^(\s+)(SizedBox\(\s*width:\s*-?\d+(?:\.\d+)?\s*\))/gm],
  // SizedBox with width and height (single line)
  [/^(\s+)(SizedBox\(\s*width:\s*-?\d+(?:\.\d+)?\s*,\s*height:\s*-?\d+(?:\.\d+)?\s*\))/gm],
  [/^(\s+)(SizedBox\(\s*height:\s*-?\d+(?:\.\d+)?\s*,\s*width:\s*-?\d+(?:\.\d+)?\s*\))/gm],
  // Empty SizedBox
  [/^(\s+)(SizedBox\(\s*\))/gm],
  // Spacer()
  [/^(\s+)(Spacer\(\s*\))/gm],
  // Divider()
  [/^(\s+)(Divider\(\s*\))/gm],
  // Divider with height/color (const-safe)
  [/^(\s+)(Divider\(\s*height:\s*\d+(?:\.\d+)?\s*\))/gm],
  // CircularProgressIndicator()
  [/^(\s+)(CircularProgressIndicator\(\s*\))/gm],
  // CircularProgressIndicator with const color
  [/^(\s+)(CircularProgressIndicator\(\s*color:\s*(?:const\s+)?(?:AppColors|AppTheme|Colors)\.\w+\s*\))/gm],
  // Icon with Icons.xxx (no args)
  [/^(\s+)(Icon\(\s*Icons\.\w+[\w_]*\s*\))/gm],
  // Icon with Icons.xxx + size (literal)
  [/^(\s+)(Icon\(\s*Icons\.\w+[\w_]*\s*,\s*size:\s*-?\d+(?:\.\d+)?\s*\))/gm],
  // Icon with Icons.xxx + color
  [/^(\s+)(Icon\(\s*Icons\.\w+[\w_]*\s*,\s*color:\s*(?:const\s+)?(?:AppColors|AppTheme|Colors)\.\w+[\w.]*\s*\))/gm],
  // Icon with Icons.xxx + color + size
  [/^(\s+)(Icon\(\s*Icons\.\w+[\w_]*\s*,\s*color:\s*(?:const\s+)?(?:AppColors|AppTheme|Colors)\.\w+[\w.]*\s*,\s*size:\s*-?\d+(?:\.\d+)?\s*\))/gm],
  [/^(\s+)(Icon\(\s*Icons\.\w+[\w_]*\s*,\s*size:\s*-?\d+(?:\.\d+)?\s*,\s*color:\s*(?:const\s+)?(?:AppColors|AppTheme|Colors)\.\w+[\w.]*\s*\))/gm],
  // Text with literal string (no interpolation)
  [/^(\s+)(Text\(\s*'[^']*'\s*\))/gm],
  [/^(\s+)(Text\(\s*"[^"$]*"\s*\))/gm],
  // Text with literal string + style (const-safe)  
  [/^(\s+)(Text\(\s*'[^']*'\s*,\s*style:\s*(?:const\s+)?TextStyle\([^)]*\)\s*\))/gm],
  // Text with literal + textAlign
  [/^(\s+)(Text\(\s*'[^']*'\s*,\s*textAlign:\s*TextAlign\.\w+\s*\))/gm],
  // Text with literal + overflow
  [/^(\s+)(Text\(\s*'[^']*'\s*,\s*overflow:\s*TextOverflow\.\w+\s*\))/gm],
  // Text with literal + maxLines
  [/^(\s+)(Text\(\s*'[^']*'\s*,\s*maxLines:\s*\d+\s*\))/gm],
  // IgnorePointer()
  [/^(\s+)(IgnorePointer\(\s*\))/gm],
  // AbsorbPointer()
  [/^(\s+)(AbsorbPointer\(\s*\))/gm],
  // Offstage()
  [/^(\s+)(Offstage\(\s*\))/gm],
  // Positioned.fill() etc with no args
  [/^(\s+)(Positioned\.fill\(\s*\))/gm],
  // Opacity(opacity: 0.5)
  [/^(\s+)(Opacity\(\s*opacity:\s*-?\d+(?:\.\d+)?\s*\))/gm],
];

let totalChanges = 0;

for (const file of files) {
  const filePath = path.resolve(file);
  if (!fs.existsSync(filePath)) {
    console.log("  SKIP: " + file);
    continue;
  }
  let content = fs.readFileSync(filePath, "utf8");
  const original = content;

  for (const [re] of linePatterns) {
    content = content.replace(re, (match, indent, widget) => {
      return indent + "const " + widget;
    });
  }

  // Fix any double-const
  content = content.replace(/\bconst const\b/g, "const");

  if (content !== original) {
    fs.writeFileSync(filePath, content, "utf8");
    const origConsts = (original.match(/\bconst\b/g) || []).length;
    const newConsts = (content.match(/\bconst\b/g) || []).length;
    const diff = newConsts - origConsts;
    totalChanges += diff;
    console.log("  " + file + ": " + diff + " widget const additions");
  } else {
    console.log("  " + file + ": no changes");
  }
}

console.log("\nTotal widget const additions: " + totalChanges);
