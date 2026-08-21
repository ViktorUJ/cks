# Design: EKS Course Localization Audit Remediation 2

## Source and boundaries

For a localized chapter `tasks/eks/course/<chapter>/<language>.md`, use `tasks/eks/course/<chapter>/ru.md` as the semantic reference. Make language-specific edits only; do not touch English, Russian, labs, or unrelated localizations.

## Remediation approach

1. Review each reported occurrence in surrounding context and distinguish explanatory language from protected technical text.
2. Localize only the explanatory label or comment. In Mermaid, preserve node identifiers and relationships while translating displayed labels.
3. Keep commands and placeholders that function as technical input unchanged unless the placeholder itself is clearly human-facing and its syntax is not part of a command contract.
4. Leave the `16/tw.md` links unchanged because their paths target matching `README_TW.MD` files and a newline between Markdown label and destination remains valid.

## Verification approach

- Search the touched files for the confirmed English remnants.
- Compare heading, table, code-fence, and Mermaid-fence counts with the Russian source.
- Parse local Markdown links and confirm every lab target exists and has the current file's language suffix.
- Request Markdown diagnostics for all modified documents.
