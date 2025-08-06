## NixOS Config Commands
```

**Build (non-sudo)**
```
./scripts/build-final-image.sh
```

**Build via Flake (experimental)**
```
<insert-command-here>
```

**Search Package**
```
nix search nixpkgs <package>
```

## Utils
```
hyprctl configerrors   # Check Hyprland
tree -L 4              # View structure
git status             # Check changes
```
## Notes
- Think before you act: List steps before action, prompt user before dangerous actions.
- Read related/dependent files to gather context and status.
- Don't document anything unless the user states otherwise.
- Keep change summaries short and concise.
- Reserve bullet points for explicit lists. Write sentences otherwise.
- Use context7 tool for code documentation to to reduce avoidable errors.
- Always use diff for proposing and writing changes:
````
Diff Title:
<<<<<<< SEARCH
[exact content]
=======
[new content]
>>>>>>> REPLACE
````
- When asked, articulate on why and how the [proposed|written] changes affect the result without excessive bullet points.
- When asked, avoid styling excessively on markdown documentation. Prefer digestible paragraphs and code blocks.

### Reasoning
For any explanations, breakdown, and summaries:
- Use Why + What + How to inspire or motivate before explaining.
- Use What + How + Why to inform or instruct logically.
- Use What + Why + How to persuade by justifying before instructing.
- Use How + What + Why when demonstrating or teaching by example.

### Documenting (semi-markdown) Formatting Rules
- **Precursor: Only document when asked by user.**
- Reserve `#` usage for important disclaimers. Instead, use `##` and `###` for [sub]headers.
- Limit bullet point usage, prefer sentences for detail.
- Limit paragraphs to 3~5 sentences before newline for readability.
- When nesting code blocks, use `\`\`\`\`\`` (4 ticks) labeled with the code language (`plaintext` otherwise) for top level. Increase ticks top level for more depth.
- When referencing a [function|file|path], wrap them in `\`` (ticks) without [italic|bold] styling.
- Credits, citations, and references should be mentioned at the end/tail of the document. Plain urls are preferred over hyprlinks.
- Reserve hyprlinks for paragraph use, list urls in reference section otherwise.
- Avoid formalities ('HR talk') and instead be explicit and clear, preferring shorter words with descriptive vocabulary.

### TL:DR
- **Precursor: Only TL:DR when asked by user.**
- Use `\>` (escaped greater-than/blockquote marker) as sentence header sentence, following `\n` (newline) with another formatted sentence using [lowercase|unpunctuated) 4chan readable grammar till the end of summary.
- - Example:
```markdown
\>surprised_pikachu.jpg banana comes from trees
\>banana looks cool
\>tfw no more banana feelsbadman.jpg
```

When ENOENT, ask for a coffee and take a break.
