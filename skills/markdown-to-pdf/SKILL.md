---
name: markdown-to-pdf
description: Convert Markdown files to PDF on macOS. Use when user wants to create a PDF from markdown, export documentation, or generate printable docs. Works without LaTeX or system dependencies.
---

# Markdown to PDF Conversion

## Problem Pattern
Converting Markdown files to PDF on macOS. Many tools require LaTeX or system libraries that are painful to install.

## Solution

### Recommended: md-to-pdf (via npx)
Zero configuration, no system dependencies required:

```bash
npx md-to-pdf your-file.md
```

Output: `your-file.pdf` in the same directory.

### With Custom Output Path
```bash
npx md-to-pdf your-file.md --dest /path/to/output.pdf
```

### Batch Convert Multiple Files
```bash
npx md-to-pdf *.md
```

## Key Insights

- **md-to-pdf just works** - Uses Puppeteer/Chromium internally, no external dependencies
- **npx handles installation** - No need to globally install, runs directly
- **Supports GitHub-flavored markdown** - Tables, code blocks, task lists all work
- **CSS styling included** - Output looks professional by default

## What Doesn't Work (on macOS)

| Approach | Problem |
|----------|---------|
| `pandoc --pdf-engine=pdflatex` | Requires LaTeX (~4GB install) |
| `weasyprint` (Python) | Requires `libgobject`, `pango`, `cairo` system libs |
| `wkhtmltopdf` | Homebrew cask unavailable |
| `grip` | Renders to HTML only, no PDF |

## Advanced Options

### Custom Styling
Create a CSS file and apply it:
```bash
npx md-to-pdf your-file.md --stylesheet custom.css
```

### Configuration File
Create `.md-to-pdf.json` in project root:
```json
{
  "stylesheet": ["custom.css"],
  "pdf_options": {
    "format": "A4",
    "margin": "20mm"
  }
}
```

### Programmatic Use (Node.js/Bun)
```javascript
import { mdToPdf } from 'md-to-pdf';

const pdf = await mdToPdf({ path: 'README.md' });
fs.writeFileSync('output.pdf', pdf.content);
```

## Troubleshooting

### First run is slow
The first `npx md-to-pdf` downloads Chromium (~150MB). Subsequent runs are fast.

### PDF looks different than expected
md-to-pdf uses its own CSS. Override with `--stylesheet` for custom styling.

### Large files timeout
For very large markdown files, increase timeout:
```bash
npx md-to-pdf your-file.md --launch-options '{"timeout": 60000}'
```

## Context
- **Environment**: macOS, Node.js/npm available
- **Dependencies**: None (npx handles everything)
- **Output quality**: High (uses Chromium rendering)

## When NOT to Use
- Need LaTeX-quality typesetting → Install MacTeX + pandoc
- Converting to formats other than PDF → Use pandoc
- No Node.js/npm available → Use online converters
